//! Text injection via CGEvent — types IPA symbols into the active app.
//!
//! Uses a private CGEventSource to avoid re-triggering the event tap.
//! Events from CGEventSourceStateID::Private are not seen by HID event taps.

use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};

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
        // Clear all modifier flags — Ctrl is still physically held but
        // we need the target app to see this as plain text, not Ctrl+key
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
