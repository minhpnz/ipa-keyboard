//! Text injection via CGEvent — types IPA symbols into the active app.
//!
//! Uses a private CGEventSource to avoid re-triggering the event tap.
//! Events from CGEventSourceStateID::Private are not seen by HID event taps.

use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};
use std::io::Write;
use std::process::{Command, Stdio};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

/// Unique flag value we set on injected events so the tap can identify
/// and skip them (defense-in-depth against re-entry).
pub const INJECTED_EVENT_TAG: i64 = 0x495041; // "IPA" in hex

/// Type a Unicode string into the active application using CGEvent key events.
/// Uses a Private event source so the events bypass our own CGEvent tap.
pub fn type_text(text: &str) {
    // Private source: events won't be seen by HID-level event taps
    let source = match CGEventSource::new(CGEventSourceStateID::Private) {
        Ok(s) => s,
        Err(_) => return,
    };

    let utf16: Vec<u16> = text.encode_utf16().collect();

    // Key-down with Unicode string
    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 0, true) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_string_from_utf16_unchecked(&utf16);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }

    // Key-up
    if let Ok(event) = CGEvent::new_keyboard_event(source, 0, false) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
}

/// Write text to the macOS pasteboard via `pbcopy`.
fn write_pasteboard(bytes: &[u8]) -> bool {
    let mut child = match Command::new("pbcopy").stdin(Stdio::piped()).spawn() {
        Ok(c) => c,
        Err(_) => return false,
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(bytes);
    }
    child.wait().is_ok()
}

/// Read current pasteboard contents via `pbpaste`. Returns `None` if the
/// pasteboard is empty or non-string (image, file refs, etc.) — in which case
/// we won't try to restore it.
fn read_pasteboard() -> Option<Vec<u8>> {
    let out = Command::new("pbpaste").output().ok()?;
    if out.stdout.is_empty() {
        None
    } else {
        Some(out.stdout)
    }
}

/// Tracks save/restore state for paste-based injection across rapid bursts
/// (e.g. cycling Ctrl+a four times in 600ms). The first injection in a burst
/// snapshots the user's clipboard; only the last to finish restores it.
struct ClipboardState {
    saved: Option<Vec<u8>>,
    pending: usize,
}

fn clipboard_state() -> &'static Mutex<ClipboardState> {
    static GUARD: OnceLock<Mutex<ClipboardState>> = OnceLock::new();
    GUARD.get_or_init(|| {
        Mutex::new(ClipboardState {
            saved: None,
            pending: 0,
        })
    })
}

/// Send a raw space keycode + backspace to flush any active IME compose
/// buffer (e.g. VietX/Telex holding an uncommitted Vietnamese letter).
///
/// Why: when an IME has uncommitted compose state and we send Cmd+V, the
/// IME treats the Cmd-shortcut as "discard compose, forward shortcut" and
/// the user's typed prefix vanishes — `r` + Ctrl+a would paste `æ` only,
/// losing the `r`. Space is the universal Telex commit trigger: it forces
/// the IME to flush `r` to the field. We follow with a backspace to delete
/// the space we just typed, leaving the field exactly as the user expects
/// before our paste lands.
///
/// CRITICAL: we use raw keycode events (no `set_string_from_utf16`) so the
/// event flows through the active input source's pipeline. Unicode-string
/// events bypass the IME and would land directly in the field, leaving the
/// compose buffer untouched — defeating the whole point of this function.
///
/// In contexts with no active IME (ABC keyboard, Notes, TextEdit), the
/// space is inserted then immediately deleted — net no-op.
fn flush_ime_compose() {
    let source = match CGEventSource::new(CGEventSourceStateID::Private) {
        Ok(s) => s,
        Err(_) => return,
    };

    // Raw keycode 49 = Space. NO set_string — must travel through the IME.
    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 49, true) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 49, false) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }

    // Brief settle so the IME commits + space lands before our backspace.
    std::thread::sleep(Duration::from_millis(15));

    // Keycode 51 = Backspace. Deletes the space we just typed.
    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 51, true) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
    if let Ok(event) = CGEvent::new_keyboard_event(source, 51, false) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
}

/// Inject `text` by writing it to the pasteboard and posting Cmd+V.
///
/// Why: `type_text` routes through the active input source (any IME),
/// so Vietnamese-style IMEs like VietX/Telex intercept and drop the
/// non-Vietnamese IPA characters. Pasting bypasses the IME pipeline
/// entirely and is the only reliable injection method that works in
/// every app + every active input source.
///
/// The user's existing clipboard is preserved across the paste:
/// snapshotted on first injection in a burst, restored shortly after the
/// last paste lands. Bursts share one snapshot so cycling doesn't lose
/// the original clipboard or restore an intermediate IPA symbol.
pub fn paste_text(text: &str) {
    // 0. Flush any uncommitted IME compose state (e.g. VietX's `r` buffer)
    // so Cmd+V doesn't discard the user's prefix.
    flush_ime_compose();
    std::thread::sleep(Duration::from_millis(15));

    // 1. Save the user's clipboard if this is the first paste in a burst.
    {
        let mut g = match clipboard_state().lock() {
            Ok(g) => g,
            Err(_) => return,
        };
        if g.pending == 0 {
            g.saved = read_pasteboard();
        }
        g.pending += 1;
    }

    // 2. Write our IPA symbol to the pasteboard.
    if !write_pasteboard(text.as_bytes()) {
        // pbcopy failed — still need to balance the pending counter.
        let mut g = match clipboard_state().lock() {
            Ok(g) => g,
            Err(_) => return,
        };
        g.pending = g.pending.saturating_sub(1);
        return;
    }

    // 3. Post Cmd+V. We override modifier flags on our own event so the
    // user's live Ctrl-held state doesn't turn this into Ctrl+Cmd+V in
    // apps that trust event flags. Browsers query live state directly,
    // but Cmd+V is universally a paste regardless of extra modifiers.
    let source = match CGEventSource::new(CGEventSourceStateID::Private) {
        Ok(s) => s,
        Err(_) => {
            schedule_restore();
            return;
        }
    };
    let cmd_flag = CGEventFlags::CGEventFlagCommand | CGEventFlags::CGEventFlagNonCoalesced;
    // V keycode = 9
    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 9, true) {
        event.set_flags(cmd_flag);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
    if let Ok(event) = CGEvent::new_keyboard_event(source, 9, false) {
        event.set_flags(cmd_flag);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }

    schedule_restore();
}

/// Spawn a delayed restore of the user's clipboard. The delay lets the
/// paste land before we overwrite the pasteboard. Only the last spawn in
/// a burst (whose decrement brings `pending` to 0) actually restores —
/// earlier ones see a non-zero counter and bail out.
fn schedule_restore() {
    std::thread::spawn(|| {
        std::thread::sleep(Duration::from_millis(200));
        let saved_to_restore = {
            let mut g = match clipboard_state().lock() {
                Ok(g) => g,
                Err(_) => return,
            };
            g.pending = g.pending.saturating_sub(1);
            if g.pending == 0 {
                g.saved.take()
            } else {
                None
            }
        };
        if let Some(bytes) = saved_to_restore {
            write_pasteboard(&bytes);
        }
    });
}

/// Delete `count` characters backwards (simulate Backspace presses).
pub fn delete_backwards(count: usize) {
    let source = match CGEventSource::new(CGEventSourceStateID::Private) {
        Ok(s) => s,
        Err(_) => return,
    };

    // Virtual keycode 51 = Backspace
    for _ in 0..count {
        if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 51, true) {
            event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
            event.set_integer_value_field(
                core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
                INJECTED_EVENT_TAG,
            );
            event.post(CGEventTapLocation::Session);
        }
        if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 51, false) {
            event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
            event.set_integer_value_field(
                core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
                INJECTED_EVENT_TAG,
            );
            event.post(CGEventTapLocation::Session);
        }
    }
}
