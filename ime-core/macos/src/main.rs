//! IPA Keyboard Daemon — standalone binary entry point.
//! For embedded use, import `ipa_keyboard_daemon::start_event_tap()` instead.

fn main() {
    eprintln!("[ipa-daemon] IPA Keyboard Daemon starting...");
    eprintln!("[ipa-daemon] Ctrl+Space to toggle, Ctrl+letter for IPA symbols");
    ipa_keyboard_daemon::start_event_tap();
}
