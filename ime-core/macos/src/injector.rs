//! Text injection into the active app.
//!
//! The active path is the **Accessibility (AX) API**: we ask the focused UI
//! element to replace its current selection with the IPA text. This:
//!   - bypasses the keyboard event pipeline → IMEs (including Vietnamese
//!     VietX/Telex) cannot intercept and drop the character;
//!   - never touches the system clipboard → user's Cmd+C content is untouched
//!     and we never synthesize Cmd+V;
//!   - never sets any modifier flags, so we cannot collide with the user's
//!     held modifier state on other shortcuts.
//!
//! Fallback for apps that don't honor AX text writes (rare — some Electron
//! apps, custom-render games): a Unicode-string CGEvent (`type_text`). This
//! also avoids the clipboard but may be intercepted by aggressive IMEs.

use core_foundation::base::{CFRelease, CFTypeRef, TCFType};
use core_foundation::string::{CFString, CFStringRef};
use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};
use std::time::Duration;

/// Unique flag value we set on injected events so the tap can identify
/// and skip them (defense-in-depth against re-entry).
pub const INJECTED_EVENT_TAG: i64 = 0x495041; // "IPA" in hex

// --- Accessibility FFI ---------------------------------------------------
//
// ApplicationServices framework is already linked by build.rs. AXUIElement
// APIs live in its HIServices subframework.

#[repr(C)]
struct AXUIElement {
    _private: [u8; 0],
}
type AXUIElementRef = *mut AXUIElement;
type AXError = i32;
const KAX_ERROR_SUCCESS: AXError = 0;

extern "C" {
    fn AXUIElementCreateSystemWide() -> AXUIElementRef;
    fn AXUIElementCopyAttributeValue(
        element: AXUIElementRef,
        attribute: CFStringRef,
        value: *mut CFTypeRef,
    ) -> AXError;
    fn AXUIElementSetAttributeValue(
        element: AXUIElementRef,
        attribute: CFStringRef,
        value: CFTypeRef,
    ) -> AXError;
}

// --- Public injection entry point ---------------------------------------

/// Inject `text` into the active application.
///
/// Order of operations:
///   1. **`flush_ime_compose`** — sends Space + Backspace through the IME
///      pipeline. This commits any uncommitted Vietnamese (VietX/Telex)
///      compose buffer to the field so our AX insert doesn't land out of
///      order. Net no-op in non-IME contexts.
///   2. **AX text insert** at the focused element.
///   3. If AX rejects (some apps don't expose `kAXSelectedTextAttribute` as
///      writable), fall back to a Unicode CGEvent. Still no clipboard touch.
pub fn insert_text(text: &str) {
    flush_ime_compose();
    // Brief settle so IME compose-commit lands and our backspace consumes
    // the inserted space before the AX write.
    std::thread::sleep(Duration::from_millis(15));

    if ax_insert_text(text) {
        return;
    }

    // AX rejected (focused element doesn't support text writes). Try the
    // Unicode-keyboard-event path — works in most non-IME contexts.
    type_text(text);
}

/// Replace the focused element's selected text with `text` via the
/// Accessibility API. Returns true if the element accepted the write.
fn ax_insert_text(text: &str) -> bool {
    unsafe {
        let system_wide = AXUIElementCreateSystemWide();
        if system_wide.is_null() {
            return false;
        }

        let focused_attr = CFString::from_static_string("AXFocusedUIElement");
        let mut focused_ref: CFTypeRef = std::ptr::null();
        let err = AXUIElementCopyAttributeValue(
            system_wide,
            focused_attr.as_concrete_TypeRef(),
            &mut focused_ref,
        );
        CFRelease(system_wide as CFTypeRef);

        if err != KAX_ERROR_SUCCESS || focused_ref.is_null() {
            return false;
        }

        let selected_text_attr = CFString::from_static_string("AXSelectedText");
        let value = CFString::new(text);
        let result = AXUIElementSetAttributeValue(
            focused_ref as AXUIElementRef,
            selected_text_attr.as_concrete_TypeRef(),
            value.as_concrete_TypeRef() as CFTypeRef,
        );
        CFRelease(focused_ref);

        result == KAX_ERROR_SUCCESS
    }
}

// --- Fallback: Unicode CGEvent ------------------------------------------

/// Type a Unicode string into the active application using CGEvent key events.
/// Uses a Private event source so the events bypass our own CGEvent tap.
/// IMEs may intercept this path — that's why AX is preferred.
pub fn type_text(text: &str) {
    let source = match CGEventSource::new(CGEventSourceStateID::Private) {
        Ok(s) => s,
        Err(_) => return,
    };

    let utf16: Vec<u16> = text.encode_utf16().collect();

    if let Ok(event) = CGEvent::new_keyboard_event(source.clone(), 0, true) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_string_from_utf16_unchecked(&utf16);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }

    if let Ok(event) = CGEvent::new_keyboard_event(source, 0, false) {
        event.set_flags(CGEventFlags::CGEventFlagNonCoalesced);
        event.set_integer_value_field(
            core_graphics::event::EventField::EVENT_SOURCE_USER_DATA,
            INJECTED_EVENT_TAG,
        );
        event.post(CGEventTapLocation::Session);
    }
}

// --- IME compose flush --------------------------------------------------

/// Send a raw space keycode + backspace through the IME pipeline to flush
/// any active IME compose buffer (e.g. VietX/Telex holding an uncommitted
/// Vietnamese letter).
///
/// Why: when an IME has uncommitted compose state and we insert text via AX,
/// the IME's pending letter would land at the *original* compose start once
/// the user later commits, putting characters out of order. Pre-flushing
/// pins the IME's buffer into the field before our AX write moves the cursor.
///
/// Space is the universal Telex commit trigger. Backspace deletes the
/// space afterward, leaving the field exactly as the user expected.
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

// --- Cycle backspace ----------------------------------------------------

/// Delete `count` characters backwards (simulate Backspace presses).
/// Used when cycling Ctrl+letter to remove the previously-inserted variant.
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
