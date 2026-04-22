//! IPA Keyboard Daemon library — CGEvent tap for system-wide IPA input.

pub mod event_tap;
pub mod injector;

use ipa_mapping_engine::MappingEngine;
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};

/// Global flag to enable/disable IPA input.
static IPA_ENABLED: AtomicBool = AtomicBool::new(true);

/// Set when the app needs to restart after Accessibility permission is granted mid-run.
static NEEDS_RESTART: AtomicBool = AtomicBool::new(false);

/// Event tap installation status.
/// 0 = pending, 1 = installed OK, 2 = failed (no accessibility), 3 = failed (other)
static TAP_STATUS: AtomicU8 = AtomicU8::new(0);

/// Get the tap installation status: 0=pending, 1=ok, 2=no-accessibility, 3=other-error
pub fn tap_status() -> u8 {
    TAP_STATUS.load(Ordering::Relaxed)
}

/// Wait up to `timeout_secs` for the tap to finish installing.
/// Returns the status (1=ok, 2=no-access, 3=error). Returns 0 if timed out.
pub fn wait_for_tap(timeout_secs: u64) -> u8 {
    let start = std::time::Instant::now();
    loop {
        let s = TAP_STATUS.load(Ordering::Relaxed);
        if s != 0 {
            return s;
        }
        if start.elapsed().as_secs() >= timeout_secs {
            return 0;
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
}

/// Toggle IPA mode on/off. Returns the new state.
pub fn toggle_ipa() -> bool {
    let new = !IPA_ENABLED.load(Ordering::Relaxed);
    IPA_ENABLED.store(new, Ordering::Relaxed);
    eprintln!("[ipa-keyboard] IPA mode: {}", if new { "ON" } else { "OFF" });
    new
}

/// Set IPA mode directly.
pub fn set_ipa_enabled(enabled: bool) {
    IPA_ENABLED.store(enabled, Ordering::Relaxed);
}

/// Check if IPA mode is currently on.
pub fn is_ipa_enabled() -> bool {
    IPA_ENABLED.load(Ordering::Relaxed)
}

/// Check if the app needs to restart (permission granted mid-run but tap failed).
pub fn needs_restart() -> bool {
    NEEDS_RESTART.load(Ordering::Relaxed)
}

/// Load the mapping engine from user config or bundled defaults.
pub fn load_engine() -> MappingEngine {
    if let Some(home) = std::env::var_os("HOME") {
        let user_config = std::path::PathBuf::from(home)
            .join("Library/Application Support/ipa-keyboard/config.json");
        if let Ok(json) = std::fs::read_to_string(&user_config) {
            if let Ok(engine) = MappingEngine::from_json(&json) {
                eprintln!("[ipa-keyboard] Loaded user config");
                return engine;
            }
        }
    }

    let fallback = include_str!("../../../shared-config/default-mappings.json");
    MappingEngine::from_json(fallback).expect("bundled default-mappings.json is invalid")
}

/// Install the event tap on the main thread's runloop (non-blocking).
/// Call this from the main thread during app setup. The main runloop
/// (e.g. Tauri's event loop) will pump events through the tap.
pub fn install_event_tap() {
    if !event_tap::check_accessibility() {
        eprintln!("[ipa-keyboard] Accessibility permission required.");
        event_tap::prompt_accessibility();

        // Poll in background until granted, then install
        std::thread::spawn(|| {
            loop {
                std::thread::sleep(std::time::Duration::from_secs(2));
                if event_tap::check_accessibility() {
                    eprintln!("[ipa-keyboard] Permission granted! Installing tap...");
                    let engine = std::sync::Arc::new(std::sync::Mutex::new(load_engine()));
                    event_tap::install_tap(engine);

                    // Wait for tap to finish installing
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    let status = TAP_STATUS.load(std::sync::atomic::Ordering::Relaxed);
                    if status != 1 {
                        // Tap failed even though permission was granted.
                        // macOS (especially Sequoia) caches the denial for the
                        // process lifetime. The app must restart.
                        eprintln!("[ipa-keyboard] Tap failed after permission grant (status={}). Restarting...", status);
                        NEEDS_RESTART.store(true, std::sync::atomic::Ordering::Relaxed);
                    }
                    return;
                }
            }
        });
        return;
    }

    let engine = std::sync::Arc::new(std::sync::Mutex::new(load_engine()));
    eprintln!("[ipa-keyboard] IPA mode: ON");
    event_tap::install_tap(engine);
}

/// Start the IPA event tap. **Blocks the calling thread** (runs CFRunLoop).
/// Use this for the standalone daemon binary.
pub fn start_event_tap() {
    if !event_tap::check_accessibility() {
        eprintln!("[ipa-keyboard] Accessibility permission required.");
        event_tap::prompt_accessibility();
        loop {
            std::thread::sleep(std::time::Duration::from_secs(2));
            if event_tap::check_accessibility() {
                eprintln!("[ipa-keyboard] Permission granted!");
                break;
            }
        }
    }

    let engine = std::sync::Arc::new(std::sync::Mutex::new(load_engine()));
    eprintln!("[ipa-keyboard] IPA mode: ON");
    event_tap::run_event_tap(engine);
}
