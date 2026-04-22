//! ITfKeyEventSink — handles key events from the TSF thread manager.
//!
//! Intercepts Ctrl+letter to cycle IPA symbols and Ctrl+Space to toggle mode.

use windows::core::*;
use windows::Win32::Foundation::*;
use windows::Win32::UI::Input::KeyboardAndMouse::*;
use windows::Win32::UI::TextServices::*;

use crate::text_input_processor::IpaTextInputProcessor_Impl;
use crate::GUID_IPA_PROFILE;

/// GUID for the Ctrl+Space preserved key (mode toggle).
const GUID_PRESERVED_KEY_TOGGLE: GUID =
    GUID::from_u128(0xAABBCCDD_1122_3344_5566_778899AABBCC);

/// Register Ctrl+Space as a preserved key.
pub fn register_preserved_keys(thread_mgr: &ITfThreadMgr, client_id: u32) -> Result<()> {
    unsafe {
        let keystroke_mgr: ITfKeystrokeMgr = thread_mgr.cast()?;

        // Ctrl+Space
        let pk = TF_PRESERVEDKEY {
            uVKey: VK_SPACE.0 as u32,
            uModifiers: TF_MOD_CONTROL,
        };
        keystroke_mgr.PreserveKey(
            client_id,
            &GUID_PRESERVED_KEY_TOGGLE,
            &pk,
            &[0u16], // empty description
            0,
        )?;
    }
    Ok(())
}

/// Unregister preserved keys.
pub fn unregister_preserved_keys(thread_mgr: &ITfThreadMgr, _client_id: u32) -> Result<()> {
    unsafe {
        let keystroke_mgr: ITfKeystrokeMgr = thread_mgr.cast()?;

        let pk = TF_PRESERVEDKEY {
            uVKey: VK_SPACE.0 as u32,
            uModifiers: TF_MOD_CONTROL,
        };
        let _ = keystroke_mgr.UnpreserveKey(&GUID_PRESERVED_KEY_TOGGLE, &pk);
    }
    Ok(())
}

/// Convert a virtual key code to a lowercase letter, if it's A-Z.
fn vkey_to_letter(vkey: u32) -> Option<char> {
    if (0x41..=0x5A).contains(&vkey) {
        Some((vkey as u8 + 32) as char) // lowercase
    } else {
        None
    }
}

/// Check if Ctrl is held (but not Alt, to avoid AltGr combinations).
fn is_ctrl_only() -> bool {
    unsafe {
        let ctrl = GetKeyState(VK_CONTROL.0.into()) < 0;
        let alt = GetKeyState(VK_MENU.0.into()) < 0;
        ctrl && !alt
    }
}

impl ITfKeyEventSink_Impl for IpaTextInputProcessor_Impl {
    fn OnSetFocus(&self, _fforeground: BOOL) -> Result<()> {
        // Reset cycling state when focus changes
        let _ = self.this.with_state(|state| {
            state.engine.reset();
            Ok(())
        });
        Ok(())
    }

    fn OnTestKeyDown(
        &self,
        _pic: Option<&ITfContext>,
        wparam: WPARAM,
        _lparam: LPARAM,
    ) -> Result<BOOL> {
        // Return TRUE if we want to handle this key in OnKeyDown
        let result = self.this.with_state(|state| {
            if !state.ipa_mode {
                return Ok(FALSE);
            }
            if !is_ctrl_only() {
                return Ok(FALSE);
            }
            let vkey = wparam.0 as u32;
            if let Some(ch) = vkey_to_letter(vkey) {
                let key_str = ch.to_string();
                if state.engine.has_mapping(&key_str) {
                    return Ok(TRUE);
                }
            }
            Ok(FALSE)
        });
        result.unwrap_or(Ok(FALSE))
    }

    fn OnKeyDown(
        &self,
        pic: Option<&ITfContext>,
        wparam: WPARAM,
        _lparam: LPARAM,
    ) -> Result<BOOL> {
        let context = pic.ok_or(Error::from(E_INVALIDARG))?;

        self.this.with_state(|state| {
            if !state.ipa_mode || !is_ctrl_only() {
                return Ok(FALSE);
            }

            let vkey = wparam.0 as u32;
            let ch = match vkey_to_letter(vkey) {
                Some(c) => c,
                None => return Ok(FALSE),
            };

            let key_str = ch.to_string();
            let result = match state.engine.cycle_next(&key_str) {
                Some(r) => r,
                None => return Ok(FALSE),
            };

            // Insert or replace the symbol via TSF composition
            if result.is_replace {
                state
                    .composition
                    .replace_text(context, state.client_id, &result.symbol)?;
            } else {
                state
                    .composition
                    .insert_text(context, state.client_id, &result.symbol)?;
            }

            Ok(TRUE)
        })?
    }

    fn OnTestKeyUp(
        &self,
        _pic: Option<&ITfContext>,
        _wparam: WPARAM,
        _lparam: LPARAM,
    ) -> Result<BOOL> {
        Ok(FALSE)
    }

    fn OnKeyUp(
        &self,
        _pic: Option<&ITfContext>,
        _wparam: WPARAM,
        _lparam: LPARAM,
    ) -> Result<BOOL> {
        Ok(FALSE)
    }

    fn OnPreservedKey(
        &self,
        _pic: Option<&ITfContext>,
        rguid: *const GUID,
    ) -> Result<BOOL> {
        unsafe {
            if *rguid == GUID_PRESERVED_KEY_TOGGLE {
                self.this.with_state(|state| {
                    state.ipa_mode = !state.ipa_mode;
                    state.engine.reset();
                    state.composition.end_composition();
                    Ok(TRUE)
                })?
            } else {
                Ok(FALSE)
            }
        }
    }
}
