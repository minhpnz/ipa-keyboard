//! CGEvent tap — intercepts keyboard events system-wide.

use crate::injector;
use core_foundation::base::TCFType;
use core_foundation::runloop::{kCFRunLoopCommonModes, CFRunLoop, CFRunLoopSource};
use core_graphics::event::{CGEvent, CGEventFlags, EventField};
use foreign_types_shared::ForeignType;
use ipa_mapping_engine::{CycleResult, MappingEngine};
use std::os::raw::c_void;
use std::sync::{Arc, Mutex};

/// What the injector should do for a successful TryCycle.
/// Pure value so the decision is unit-testable without CGEvent FFI.
#[derive(Debug, PartialEq, Eq)]
pub struct InjectionPlan {
    /// Backspaces to send before typing `text`.
    pub backspaces: usize,
    /// Text to type (UTF-8) after the backspaces.
    pub text: String,
}

/// Plan the inject side-effect for a CycleResult.
///
/// - **Cycling within the timeout** (`is_replace == true`): erase the IPA
///   symbol we wrote on the previous press, then type the next one.
/// - **Fresh cycle** (`is_replace == false`) and the most recent plain
///   keystroke was the same letter as the trigger: erase that one character
///   and replace it with the IPA symbol. Vietnamese-IME-style — `a` then
///   Ctrl+a yields `æ`, not `aæ`.
/// - **Fresh cycle, prior key was something else (or nothing)**: just type
///   the IPA symbol. `r` + Ctrl+a yields `ræ`, not `æ`. Avoids spurious
///   backspaces in empty fields or after non-matching context.
///
/// `prev_symbol_len` is used only when `is_replace` is true.
/// `last_typed_letter` is the most recent plain (non-Ctrl) letter the user
/// typed since the last IPA injection; `None` means they typed something
/// non-letter (space, punctuation) or nothing.
pub fn plan_injection(
    cycle_result: &CycleResult,
    prev_symbol_len: usize,
    last_typed_letter: Option<char>,
    trigger_letter: char,
) -> InjectionPlan {
    if cycle_result.is_replace {
        return InjectionPlan {
            backspaces: prev_symbol_len,
            text: cycle_result.symbol.clone(),
        };
    }
    // Fresh cycle (post-timeout or first press):
    match last_typed_letter {
        Some(letter) if letter == trigger_letter => {
            // Match — eat the trigger and type the IPA. Vietnamese-IME style.
            InjectionPlan {
                backspaces: 1,
                text: cycle_result.symbol.clone(),
            }
        }
        _ => {
            // Non-matching prior letter or no prior context: append the IPA
            // symbol with no backspace. The earlier backspace+retype scheme
            // (delete the prior letter, re-type it together with the IPA)
            // raced badly with browser/VietX keystroke commit ordering and
            // produced visible doubling like `rræ` when the backspace was
            // dropped or reinterpreted. Simple append is robust everywhere.
            InjectionPlan {
                backspaces: 0,
                text: cycle_result.symbol.clone(),
            }
        }
    }
}

// Raw C bindings not exposed by the core-graphics crate
extern "C" {
    fn AXIsProcessTrusted() -> bool;
    fn AXIsProcessTrustedWithOptions(options: *const c_void) -> bool;
    fn CGEventTapEnable(tap: *mut c_void, enable: bool);
    fn CGEventTapIsEnabled(tap: *mut c_void) -> bool;
    fn CFMachPortCreateRunLoopSource(
        allocator: *const c_void,
        tap: *mut c_void,
        order: i64,
    ) -> *mut c_void;
}

/// Check if the app has Accessibility permission.
pub fn check_accessibility() -> bool {
    unsafe { AXIsProcessTrusted() }
}

/// Prompt the system accessibility permission dialog.
pub fn prompt_accessibility() {
    use core_foundation::boolean::CFBoolean;
    use core_foundation::dictionary::CFDictionary;
    use core_foundation::string::CFString;

    let key = CFString::new("AXTrustedCheckOptionPrompt");
    let value = CFBoolean::true_value();
    let options = CFDictionary::from_CFType_pairs(&[(key, value)]);
    unsafe {
        AXIsProcessTrustedWithOptions(options.as_concrete_TypeRef() as *const c_void);
    }
}

/// Global tap reference for re-enabling from the callback.
static mut GLOBAL_TAP: *mut c_void = std::ptr::null_mut();

/// Shared state passed into the CGEvent callback.
struct TapState {
    engine: Arc<Mutex<MappingEngine>>,
    last_symbol_len: usize,
    /// Most recent plain (non-Ctrl) letter the user typed. Used to decide
    /// whether a fresh Ctrl+letter should eat the prior char (Vietnamese-IME
    /// style) or just append. Cleared on space/punctuation/Tab/Return/etc.,
    /// after each IPA injection, and on IPA toggle.
    last_typed_letter: Option<char>,
}

/// Decision a key event demands before any engine side-effects.
/// Factored out of `tap_callback` so it can be unit-tested without CGEvent FFI.
#[derive(Debug, PartialEq, Eq)]
pub enum KeyAction {
    /// Forward the event to the focused app unchanged.
    PassThrough,
    /// Swallow the event entirely (the focused app never sees it).
    Suppress,
    /// Toggle IPA mode on/off (Ctrl+Space).
    ToggleIpa,
    /// No Ctrl — reset any in-flight cycle state, then pass through.
    ResetAndPassThrough,
    /// Ctrl+mapped-keycode while IPA is on — ask the mapping engine
    /// to produce/cycle the symbol for this letter.
    TryCycle(char),
}

/// Pure decision function: given the IPA state, active modifiers, and keycode,
/// decide what to do with the event. No side effects, no FFI — safe to unit-test.
///
/// Rules:
/// - Cmd or Option held → pass through (Cmd+C/V/Z, Option+letter, etc. must work).
/// - No Ctrl held → pass through (plain typing) after resetting cycle state.
/// - Ctrl+Space → toggle IPA mode (works regardless of current state).
/// - Ctrl+key, IPA off → pass through (keep default macOS behavior).
/// - Ctrl+key, IPA on, keycode maps to a letter → hand to mapping engine.
/// - Ctrl+key, IPA on, unmapped printable keycode → suppress
///   (blocks macOS Emacs-style bindings: Ctrl+/, Ctrl+K, Ctrl+W, Ctrl+T, etc.).
/// - Ctrl+key, IPA on, navigation keycode (Tab, Return, arrows, fn-keys) → pass through.
pub fn decide_key_action(
    ipa_enabled: bool,
    has_ctrl: bool,
    has_cmd: bool,
    has_opt: bool,
    keycode: u16,
) -> KeyAction {
    if has_cmd || has_opt {
        return KeyAction::PassThrough;
    }
    if !has_ctrl {
        return KeyAction::ResetAndPassThrough;
    }
    if keycode == 49 {
        return KeyAction::ToggleIpa;
    }
    if !ipa_enabled {
        return KeyAction::PassThrough;
    }
    if let Some(letter) = keycode_to_letter(keycode) {
        return KeyAction::TryCycle(letter);
    }
    if is_printable_character_key(keycode) {
        KeyAction::Suppress
    } else {
        KeyAction::PassThrough
    }
}

/// The CGEvent tap callback. Called for every keyboard event system-wide.
unsafe extern "C" fn tap_callback(
    _proxy: *mut c_void,
    event_type: u32,
    event: *mut c_void,
    user_info: *mut c_void,
) -> *mut c_void {
    // CGEventType::KeyDown = 10
    const KEY_DOWN: u32 = 10;
    // CGEventType::TapDisabledByTimeout = 0xFFFFFFFE
    const TAP_DISABLED: u32 = 0xFFFFFFFE;

    if event_type == TAP_DISABLED {
        eprintln!("[ipa-daemon] Tap was disabled by timeout, re-enabling...");
        if !GLOBAL_TAP.is_null() {
            CGEventTapEnable(GLOBAL_TAP, true);
            eprintln!("[ipa-daemon] Tap re-enabled.");
        }
        return event;
    }

    if event_type != KEY_DOWN {
        return event;
    }

    let state = &mut *(user_info as *mut TapState);

    // Wrap the raw event pointer into a CGEvent (borrowing, no ownership transfer)
    let cg_event = CGEvent::from_ptr(event as *mut _);

    // Skip events we injected ourselves (defense-in-depth)
    let user_data = cg_event.get_integer_value_field(EventField::EVENT_SOURCE_USER_DATA);
    if user_data == injector::INJECTED_EVENT_TAG {
        std::mem::forget(cg_event);
        return event;
    }

    let flags = cg_event.get_flags();
    let has_ctrl = flags.contains(CGEventFlags::CGEventFlagControl);
    let has_cmd = flags.contains(CGEventFlags::CGEventFlagCommand);
    let has_opt = flags.contains(CGEventFlags::CGEventFlagAlternate);

    let keycode = cg_event.get_integer_value_field(EventField::KEYBOARD_EVENT_KEYCODE) as u16;

    let action = decide_key_action(
        crate::is_ipa_enabled(),
        has_ctrl,
        has_cmd,
        has_opt,
        keycode,
    );

    match action {
        KeyAction::PassThrough => {
            std::mem::forget(cg_event);
            event
        }
        KeyAction::Suppress => {
            std::mem::forget(cg_event);
            std::ptr::null_mut()
        }
        KeyAction::ToggleIpa => {
            eprintln!("[ipa-daemon] Ctrl+Space pressed, toggling IPA mode");
            crate::toggle_ipa();
            if let Ok(mut engine) = state.engine.lock() {
                engine.reset();
            }
            state.last_symbol_len = 0;
            state.last_typed_letter = None;
            std::mem::forget(cg_event);
            std::ptr::null_mut()
        }
        KeyAction::ResetAndPassThrough => {
            if state.last_symbol_len > 0 {
                if let Ok(mut engine) = state.engine.lock() {
                    engine.reset();
                }
                state.last_symbol_len = 0;
            }
            // Track the most recent plain letter typed (or clear if it was
            // space, punctuation, return, etc.) so a follow-up Ctrl+letter
            // can decide whether to eat the trigger.
            state.last_typed_letter = keycode_to_letter(keycode);
            std::mem::forget(cg_event);
            event
        }
        KeyAction::TryCycle(letter) => {
            let result = {
                let mut engine = match state.engine.lock() {
                    Ok(e) => e,
                    Err(_) => {
                        std::mem::forget(cg_event);
                        return event;
                    }
                };
                engine.cycle_next(&letter.to_string())
            };

            match result {
                Some(cycle_result) => {
                    std::mem::forget(cg_event);
                    let plan = plan_injection(
                        &cycle_result,
                        state.last_symbol_len,
                        state.last_typed_letter,
                        letter,
                    );
                    if plan.backspaces > 0 {
                        injector::delete_backwards(plan.backspaces);
                    }
                    // Always settle briefly before injecting. Without this,
                    // the Ctrl modifier state from the suppressed Ctrl+letter
                    // event can bleed into our injected events.
                    std::thread::sleep(std::time::Duration::from_millis(10));
                    // AX-based injection: writes directly to the focused UI
                    // element via the Accessibility API. Bypasses both the
                    // IME pipeline (so VietX/Telex can't intercept) and the
                    // clipboard (so the user's Cmd+C content is untouched).
                    injector::insert_text(&plan.text);
                    // Only the IPA portion is what a subsequent in-timeout
                    // cycle needs to backspace. Counting `plan.text` would
                    // over-count if the plan ever prepends/appends extra
                    // chars (e.g. a re-typed prior letter), causing the next
                    // cycle to delete user text.
                    state.last_symbol_len = cycle_result.symbol.chars().count();
                    // After an IPA injection the prior plain-letter context
                    // is consumed (or irrelevant); subsequent fresh cycles
                    // should not eat anything.
                    state.last_typed_letter = None;
                    std::ptr::null_mut()
                }
                None => {
                    // Engine has no IPA mapping for this letter (e.g. Ctrl+F,
                    // Ctrl+K, Ctrl+X). Suppress so the underlying macOS Emacs
                    // binding doesn't fire and mangle the user's text. Leave
                    // last_typed_letter alone — no character was injected.
                    state.last_symbol_len = 0;
                    std::mem::forget(cg_event);
                    std::ptr::null_mut()
                }
            }
        }
    }
}

/// Map macOS virtual keycode to ASCII letter.
pub fn keycode_to_letter(keycode: u16) -> Option<char> {
    match keycode {
        0 => Some('a'),
        1 => Some('s'),
        2 => Some('d'),
        3 => Some('f'),
        4 => Some('h'),
        5 => Some('g'),
        6 => Some('z'),
        7 => Some('x'),
        8 => Some('c'),
        9 => Some('v'),
        11 => Some('b'),
        12 => Some('q'),
        13 => Some('w'),
        14 => Some('e'),
        15 => Some('r'),
        16 => Some('y'),
        17 => Some('t'),
        18 => Some('1'),
        19 => Some('2'),
        20 => Some('3'),
        21 => Some('4'),
        22 => Some('6'),
        23 => Some('5'),
        25 => Some('9'),
        26 => Some('7'),
        28 => Some('8'),
        29 => Some('0'),
        31 => Some('o'),
        32 => Some('u'),
        34 => Some('i'),
        35 => Some('p'),
        37 => Some('l'),
        38 => Some('j'),
        40 => Some('k'),
        45 => Some('n'),
        46 => Some('m'),
        _ => None,
    }
}

/// Keycodes that produce printable characters on a US keyboard.
/// Excludes Return (36), Tab (48), Space (49), Backspace (51), Escape (53),
/// arrows (123-126), and function keys — those stay passable under Ctrl
/// so navigation / app shortcuts still work.
pub fn is_printable_character_key(keycode: u16) -> bool {
    matches!(keycode, 0..=35 | 37..=47 | 50)
}

// Raw C binding for CGEventTapCreate
extern "C" {
    fn CGEventTapCreate(
        tap: u32,       // CGEventTapLocation
        place: u32,     // CGEventTapPlacement
        options: u32,   // CGEventTapOptions
        events_of_interest: u64,
        callback: unsafe extern "C" fn(*mut c_void, u32, *mut c_void, *mut c_void) -> *mut c_void,
        user_info: *mut c_void,
    ) -> *mut c_void;
}

/// Create the tap, add to main runloop, enable it. Does NOT block.
fn create_and_install_tap(state_ptr: *mut c_void) {
    let event_mask: u64 = (1 << 10) | (1 << 12);

    let tap = unsafe {
        CGEventTapCreate(
            0, // kCGHIDEventTap
            0, // kCGHeadInsertEventTap
            0, // kCGEventTapOptionDefault
            event_mask,
            tap_callback,
            state_ptr,
        )
    };

    if tap.is_null() {
        eprintln!("[ipa-daemon] ERROR: Failed to create CGEvent tap.");
        eprintln!("[ipa-daemon] Make sure Accessibility permission is granted.");
        crate::TAP_STATUS.store(2, std::sync::atomic::Ordering::Relaxed);
        return;
    }

    unsafe {
        GLOBAL_TAP = tap;

        let source = CFMachPortCreateRunLoopSource(std::ptr::null(), tap, 0);
        if source.is_null() {
            eprintln!("[ipa-daemon] ERROR: Failed to create run loop source");
            crate::TAP_STATUS.store(3, std::sync::atomic::Ordering::Relaxed);
            return;
        }

        let rl_source = CFRunLoopSource::wrap_under_create_rule(source as *mut _);
        // Try both main and current runloop to ensure delivery
        let main_rl = CFRunLoop::get_main();
        let current_rl = CFRunLoop::get_current();
        main_rl.add_source(&rl_source, kCFRunLoopCommonModes);
        if main_rl.as_CFType() != current_rl.as_CFType() {
            eprintln!("[ipa-daemon] Note: current thread is not main, added to main RL");
        }
        CGEventTapEnable(tap, true);
    }

    crate::TAP_STATUS.store(1, std::sync::atomic::Ordering::Relaxed);
    eprintln!("[ipa-daemon] Event tap installed. Running...");

    // Spawn a watchdog thread that periodically re-enables the tap.
    // macOS can silently disable taps on timeout, sleep/wake, or screen lock.
    // The TapDisabledByTimeout callback isn't always reliable.
    std::thread::spawn(|| {
        loop {
            std::thread::sleep(std::time::Duration::from_secs(5));
            unsafe {
                if !GLOBAL_TAP.is_null() && !CGEventTapIsEnabled(GLOBAL_TAP) {
                    eprintln!("[ipa-daemon] Watchdog: tap was disabled, re-enabling...");
                    CGEventTapEnable(GLOBAL_TAP, true);
                }
            }
        }
    });
}

// dispatch_get_main_queue() is a macro in C; the actual symbol is _dispatch_main_q
extern "C" {
    static _dispatch_main_q: c_void;
    fn dispatch_async_f(queue: *const c_void, context: *mut c_void, work: extern "C" fn(*mut c_void));
}

extern "C" fn dispatch_install_tap(context: *mut c_void) {
    create_and_install_tap(context);
}

/// Install the CGEvent tap on the main runloop via GCD. Non-blocking.
/// Schedules tap creation on the main dispatch queue to guarantee
/// it runs on the actual Cocoa main thread.
pub fn install_tap(engine: Arc<Mutex<MappingEngine>>) {
    let state = Box::new(TapState {
        engine,
        last_symbol_len: 0,
        last_typed_letter: None,
    });
    let state_ptr = Box::into_raw(state) as *mut c_void;

    unsafe {
        let main_queue = &_dispatch_main_q as *const c_void;
        dispatch_async_f(main_queue, state_ptr, dispatch_install_tap);
    }
    eprintln!("[ipa-daemon] Scheduled event tap install on main queue");
}

/// Install the CGEvent tap and run the event loop. **Blocks forever.**
/// Use for the standalone daemon binary.
pub fn run_event_tap(engine: Arc<Mutex<MappingEngine>>) {
    let state = Box::new(TapState {
        engine,
        last_symbol_len: 0,
        last_typed_letter: None,
    });
    let state_ptr = Box::into_raw(state) as *mut c_void;
    create_and_install_tap(state_ptr);
    CFRunLoop::run_current();
}

#[cfg(test)]
mod plan_injection_tests {
    use super::*;

    fn cycle(symbol: &str, is_replace: bool) -> CycleResult {
        CycleResult {
            symbol: symbol.to_string(),
            is_replace,
        }
    }

    /// Fresh cycle, prior plain key was the trigger letter: backspace one
    /// to consume the user-typed `a` and replace with `æ`.
    #[test]
    fn fresh_cycle_eats_trigger_when_prior_letter_matches() {
        let plan = plan_injection(&cycle("æ", false), 0, Some('a'), 'a');
        assert_eq!(
            plan,
            InjectionPlan {
                backspaces: 1,
                text: "æ".to_string()
            }
        );
    }

    /// Fresh cycle, prior plain key was a different letter: simple append.
    /// `r` then Ctrl+a yields `ræ` by leaving the user's `r` alone and just
    /// inserting `æ`. The earlier backspace+retype workaround raced with
    /// browser/VietX keystroke commit ordering and produced `rræ`.
    #[test]
    fn fresh_cycle_non_matching_prior_letter_appends_ipa_only() {
        let plan = plan_injection(&cycle("æ", false), 0, Some('r'), 'a');
        assert_eq!(plan.backspaces, 0);
        assert_eq!(plan.text, "æ");
    }

    /// Fresh cycle with no plain letter context (empty field, after space,
    /// after a previous IPA injection, etc.): emit no backspace.
    #[test]
    fn fresh_cycle_with_no_prior_letter_emits_no_backspace() {
        let plan = plan_injection(&cycle("æ", false), 0, None, 'a');
        assert_eq!(plan.backspaces, 0);
        assert_eq!(plan.text, "æ");
    }

    /// Fresh cycle ignores `prev_symbol_len` regardless of context — only
    /// `is_replace == true` consults it.
    #[test]
    fn fresh_cycle_ignores_stale_prev_symbol_len() {
        let plan = plan_injection(&cycle("æ", false), 99, Some('a'), 'a');
        assert_eq!(plan.backspaces, 1);
    }

    /// Cycling within timeout: backspace the previous IPA symbol's char
    /// count (it may be 1 like `æ`, or 2 like `ɑː`/`tʃ`), then type next.
    /// `last_typed_letter` is irrelevant in this branch.
    #[test]
    fn cycling_replaces_prior_symbol_one_char() {
        let plan = plan_injection(&cycle("ʌ", true), 1, None, 'a');
        assert_eq!(plan.backspaces, 1);
        assert_eq!(plan.text, "ʌ");
    }

    #[test]
    fn cycling_replaces_prior_symbol_two_chars() {
        let plan = plan_injection(&cycle("ɑ", true), 2, None, 'a');
        assert_eq!(plan.backspaces, 2);
        assert_eq!(plan.text, "ɑ");
    }

    /// Cycling ignores `last_typed_letter` even if it happens to match —
    /// the symbol-length count is the source of truth when replacing.
    #[test]
    fn cycling_ignores_last_typed_letter() {
        let plan = plan_injection(&cycle("ʌ", true), 1, Some('a'), 'a');
        assert_eq!(plan.backspaces, 1);
    }

    /// Defensive: if the engine flags `is_replace` but we somehow have
    /// no prior length recorded, the plan emits zero backspaces.
    #[test]
    fn cycling_with_zero_prev_len_emits_no_backspace() {
        let plan = plan_injection(&cycle("ʌ", true), 0, None, 'a');
        assert_eq!(plan.backspaces, 0);
        assert_eq!(plan.text, "ʌ");
    }
}
