use tauri::menu::{AboutMetadataBuilder, MenuBuilder, MenuItemBuilder, SubmenuBuilder};
use tauri::tray::TrayIconBuilder;
use tauri::{image::Image, Manager};

/// Uninstall: remove config, reset Accessibility permission, delete app bundle.
fn uninstall() {
    if let Some(home) = std::env::var_os("HOME") {
        let config_dir = std::path::PathBuf::from(&home)
            .join("Library/Application Support/ipa-keyboard");
        if config_dir.exists() {
            let _ = std::fs::remove_dir_all(&config_dir);
        }
    }

    // Remove from Accessibility list
    let _ = std::process::Command::new("tccutil")
        .args(["reset", "Accessibility", "com.minhphan.ipa-keyboard"])
        .output();

    if let Ok(exe) = std::env::current_exe() {
        if let Some(app_bundle) = exe.parent()
            .and_then(|p| p.parent())
            .and_then(|p| p.parent())
        {
            if app_bundle.extension().map(|e| e == "app").unwrap_or(false) {
                let _ = std::fs::remove_dir_all(app_bundle);
            }
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            // --- Install CGEvent tap on main runloop (non-blocking) ---
            ipa_keyboard_daemon::install_event_tap();

            // --- Monitor tap status and auto-restart if needed ---
            let app_handle = app.handle().clone();
            std::thread::spawn(move || {
                // First, wait for initial tap result
                let status = ipa_keyboard_daemon::wait_for_tap(10);
                if status == 1 {
                    // Tap installed OK on first try
                    return;
                }

                // Tap didn't install yet (waiting for Accessibility permission).
                // Poll until either tap succeeds or needs_restart is set.
                loop {
                    std::thread::sleep(std::time::Duration::from_secs(1));

                    if ipa_keyboard_daemon::needs_restart() {
                        // Permission was granted but tap failed — macOS requires restart.
                        eprintln!("[ipa-keyboard] Auto-restarting after permission grant...");

                        // Relaunch the app
                        let exe = std::env::current_exe().ok();
                        if let Some(app_bundle) = exe.as_ref()
                            .and_then(|p| p.parent())
                            .and_then(|p| p.parent())
                            .and_then(|p| p.parent())
                        {
                            let bundle_path = app_bundle.to_path_buf();
                            let _ = std::process::Command::new("open")
                                .arg("-a")
                                .arg(&bundle_path)
                                .spawn();
                        }
                        // Exit current instance
                        app_handle.exit(0);
                        return;
                    }

                    let s = ipa_keyboard_daemon::tap_status();
                    if s == 1 {
                        eprintln!("[ipa-keyboard] Tap installed after permission grant!");
                        return;
                    }
                }
            });

            // --- Native macOS menu bar ---
            let about_meta = AboutMetadataBuilder::new()
                .name(Some("IPA Keyboard"))
                .version(Some(env!("CARGO_PKG_VERSION")))
                .comments(Some("International Phonetic Alphabet input tool"))
                .build();

            let app_menu = SubmenuBuilder::new(app, "IPA Keyboard")
                .about(Some(about_meta))
                .separator()
                .services()
                .separator()
                .hide()
                .hide_others()
                .show_all()
                .separator()
                .quit()
                .build()?;

            let file_menu = SubmenuBuilder::new(app, "File")
                .close_window()
                .build()?;

            let edit_menu = SubmenuBuilder::new(app, "Edit")
                .undo()
                .redo()
                .separator()
                .cut()
                .copy()
                .paste()
                .separator()
                .select_all()
                .build()?;

            let view_menu = SubmenuBuilder::new(app, "View")
                .fullscreen()
                .build()?;

            let window_menu = SubmenuBuilder::new(app, "Window")
                .minimize()
                .maximize()
                .separator()
                .close_window()
                .build()?;

            let menu = MenuBuilder::new(app)
                .item(&app_menu)
                .item(&file_menu)
                .item(&edit_menu)
                .item(&view_menu)
                .item(&window_menu)
                .build()?;

            app.set_menu(menu)?;

            // --- System tray icon ---
            let tray_icon = Image::from_bytes(include_bytes!("../icons/tray-icon@2x-active.png"))?;

            let toggle_item =
                MenuItemBuilder::with_id("toggle", "Disable IPA Input").build(app)?;
            let show_item =
                MenuItemBuilder::with_id("show", "Show IPA Keyboard").build(app)?;
            let uninstall_item =
                MenuItemBuilder::with_id("uninstall", "Uninstall...").build(app)?;
            let quit_item = MenuItemBuilder::with_id("quit", "Quit").build(app)?;
            let tray_menu = MenuBuilder::new(app)
                .items(&[&toggle_item, &show_item, &uninstall_item, &quit_item])
                .build()?;

            // Clone toggle_item so we can update its text without rebuilding the menu
            let toggle_item_ref = toggle_item.clone();

            TrayIconBuilder::with_id("main-tray")
                .menu(&tray_menu)
                .tooltip("IPA Keyboard — Enabled")
                .icon(tray_icon)
                .icon_as_template(false)
                .on_menu_event(move |app, event| match event.id().as_ref() {
                    "toggle" => {
                        let new_enabled = ipa_keyboard_daemon::toggle_ipa();

                        // Update existing menu item text instead of rebuilding the menu
                        let label = if new_enabled {
                            "Disable IPA Input"
                        } else {
                            "Enable IPA Input"
                        };
                        let _ = toggle_item_ref.set_text(label);

                        if let Some(tray) = app.tray_by_id("main-tray") {
                            let tooltip = if new_enabled {
                                "IPA Keyboard — Enabled"
                            } else {
                                "IPA Keyboard — Disabled"
                            };
                            let _ = tray.set_tooltip(Some(tooltip));
                            let icon_bytes: &[u8] = if new_enabled {
                                include_bytes!("../icons/tray-icon@2x-active.png")
                            } else {
                                include_bytes!("../icons/tray-icon@2x-inactive.png")
                            };
                            if let Ok(icon) = Image::from_bytes(icon_bytes) {
                                let _ = tray.set_icon(Some(icon));
                                // Template mode only for active — inactive renders as-is (gray)
                            }
                        }
                    }
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "uninstall" => {
                        let app_handle = app.clone();
                        tauri::async_runtime::spawn(async move {
                            use tauri_plugin_dialog::DialogExt;
                            let confirmed = app_handle
                                .dialog()
                                .message("This will remove user settings and move IPA Keyboard to Trash.\n\nAre you sure?")
                                .title("Uninstall IPA Keyboard")
                                .blocking_show();
                            if confirmed {
                                uninstall();
                                app_handle.exit(0);
                            }
                        });
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .build(app)?;

            // Watch for Ctrl+Space toggle changes and sync tray icon/menu
            let app_handle2 = app.handle().clone();
            let toggle_item_sync = toggle_item.clone();
            std::thread::spawn(move || {
                let mut last_state = true; // starts enabled
                loop {
                    std::thread::sleep(std::time::Duration::from_millis(500));
                    let current = ipa_keyboard_daemon::is_ipa_enabled();
                    if current != last_state {
                        last_state = current;
                        let toggle_ref = toggle_item_sync.clone();
                        let handle = app_handle2.clone();
                        let _ = app_handle2.run_on_main_thread(move || {
                            let label = if current {
                                "Disable IPA Input"
                            } else {
                                "Enable IPA Input"
                            };
                            let _ = toggle_ref.set_text(label);
                            if let Some(tray) = handle.tray_by_id("main-tray") {
                                let _ = tray.set_tooltip(Some(if current {
                                    "IPA Keyboard — Enabled"
                                } else {
                                    "IPA Keyboard — Disabled"
                                }));
                                let icon_bytes: &[u8] = if current {
                                    include_bytes!("../icons/tray-icon@2x-active.png")
                                } else {
                                    include_bytes!("../icons/tray-icon@2x-inactive.png")
                                };
                                if let Ok(icon) = Image::from_bytes(icon_bytes) {
                                    let _ = tray.set_icon(Some(icon));
                                }
                            }
                        });
                    }
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
