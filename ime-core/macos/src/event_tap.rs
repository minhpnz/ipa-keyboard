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
///   symbol we wrote on the previous press, then type the next one. This is
///   the existing Ctrl+letter-cycles-variants behavior.
/// - **Fresh cycle** (`is_replace == false`): erase the *one* character the
///   user just typed (the trigger letter) and replace it with the IPA
///   symbol. This is the Vietnamese-IME-style behavior — typing `a` then
///   Ctrl+a yields `æ`, not `aæ`. Same when the prior char was unrelated:
///   `r` + Ctrl+a yields `æ`, not `ræ`.
///
/// `prev_symbol_len` is the char count of the IPA symbol injected on the
/// previous press in this cycling group, used only when `is_replace` is true.
pub fn plan_injection(cycle_result: &CycleResult, prev_symbol_len: usize) -> InjectionPlan {
    let backspaces = if cycle_result.is_replace {
        prev_symbol_len
    } else {
        1
    };
    InjectionPlan {
        backspaces,
        text: cycle_result.symbol.clone(),
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
                    let plan = plan_injection(&cycle_result, state.last_symbol_len);
                    if plan.backspaces > 0 {
                        injector::delete_backwards(plan.backspaces);
                        std::thread::sleep(std::time::Duration::from_millis(10));
                    }
                    injector::type_text(&plan.text);
                    state.last_symbol_len = plan.text.chars().count();
                    std::ptr::null_mut()
                }
                None => {
                    // Engine has no IPA mapping for this letter (e.g. Ctrl+F,
                    // Ctrl+K, Ctrl+X). Suppress so the underlying macOS Emacs
                    // binding doesn't fire and mangle the user's text.
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

    /// Fresh cycle (first Ctrl+letter, or after timeout): backspace ONE
    /// character to consume the trigger letter the user typed
    /// (Vietnamese-IME-style replacement), then type the IPA symbol.
    #[test]
    fn fresh_cycle_eats_one_trigger_char() {
        let plan = plan_injection(&cycle("æ", false), 0);
        assert_eq!(
            plan,
            InjectionPlan {
                backspaces: 1,
                text: "æ".to_string()
            }
        );
    }

    /// Fresh cycle ignores `prev_symbol_len`: even if a stale value is
    /// carried over, a fresh cycle always backspaces exactly one char.
    #[test]
    fn fresh_cycle_ignores_stale_prev_symbol_len() {
        let plan = plan_injection(&cycle("æ", false), 99);
        assert_eq!(plan.backspaces, 1);
        assert_eq!(plan.text, "æ");
    }

    /// Cycling within timeout: backspace the previous IPA symbol's char
    /// count (it may be 1 like `æ`, or 2 like `ɑː`/`tʃ`), then type next.
    #[test]
    fn cycling_replaces_prior_symbol_one_char() {
        let plan = plan_injection(&cycle("ʌ", true), 1);
        assert_eq!(plan.backspaces, 1);
        assert_eq!(plan.text, "ʌ");
    }

    #[test]
    fn cycling_replaces_prior_symbol_two_chars() {
        // e.g. previous symbol was `ɑː` (2 chars) — we erase both before
        // typing the next variant.
        let plan = plan_injection(&cycle("ɑ", true), 2);
        assert_eq!(plan.backspaces, 2);
        assert_eq!(plan.text, "ɑ");
    }

    /// Defensive: if the engine flags `is_replace` but we somehow have
    /// no prior length recorded, the plan emits zero backspaces (we can't
    /// guess what to erase).
    #[test]
    fn cycling_with_zero_prev_len_emits_no_backspace() {
        let plan = plan_injection(&cycle("ʌ", true), 0);
        assert_eq!(plan.backspaces, 0);
        assert_eq!(plan.text, "ʌ");
    }
}
