//! Windows TSF (Text Services Framework) IME for IPA input.
//!
//! This crate produces a COM DLL (`ipa_ime.dll`) that registers as a Windows
//! input method via the Text Services Framework.
//!
//! DLL exports:
//! - `DllGetClassObject` — COM class factory entry point
//! - `DllCanUnloadNow` — whether the DLL can be freed
//! - `DllRegisterServer` / `DllUnregisterServer` — self-registration

#[cfg(windows)]
mod text_input_processor;
#[cfg(windows)]
mod key_handler;
#[cfg(windows)]
mod composition;
#[cfg(windows)]
mod config_reader;
#[cfg(windows)]
mod register;

#[cfg(windows)]
use std::sync::atomic::{AtomicU32, Ordering};

#[cfg(windows)]
use windows::core::*;
#[cfg(windows)]
use windows::Win32::Foundation::*;
#[cfg(windows)]
use windows::Win32::System::Com::*;
#[cfg(windows)]
use windows::Win32::System::SystemServices::*;

#[cfg(windows)]
use text_input_processor::IpaTextInputProcessor;

/// CLSID for the IPA Keyboard TIP.
/// Generated once, must match the registration scripts.
#[cfg(windows)]
pub const CLSID_IPA_TIP: GUID = GUID::from_u128(0x7a3b8c4d_1e2f_4a5b_9c6d_8e7f0a1b2c3d);

/// Language profile GUID.
#[cfg(windows)]
pub const GUID_IPA_PROFILE: GUID = GUID::from_u128(0x4d3c2b1a_5e6f_7a8b_9c0d_1e2f3a4b5c6d);

/// Global DLL reference count — prevents unloading while COM objects are alive.
#[cfg(windows)]
static DLL_REF_COUNT: AtomicU32 = AtomicU32::new(0);

#[cfg(windows)]
static mut DLL_INSTANCE: HMODULE = HMODULE(std::ptr::null_mut());

#[cfg(windows)]
pub fn dll_add_ref() {
    DLL_REF_COUNT.fetch_add(1, Ordering::SeqCst);
}

#[cfg(windows)]
pub fn dll_release() {
    DLL_REF_COUNT.fetch_sub(1, Ordering::SeqCst);
}

// --- DLL entry points ---

#[cfg(windows)]
#[no_mangle]
unsafe extern "system" fn DllMain(
    hinstance: HMODULE,
    reason: u32,
    _reserved: *mut std::ffi::c_void,
) -> BOOL {
    if reason == DLL_PROCESS_ATTACH {
        DLL_INSTANCE = hinstance;
    }
    TRUE
}

/// COM class factory entry point.
#[cfg(windows)]
#[no_mangle]
unsafe extern "system" fn DllGetClassObject(
    rclsid: *const GUID,
    riid: *const GUID,
    ppv: *mut *mut std::ffi::c_void,
) -> HRESULT {
    if ppv.is_null() {
        return E_INVALIDARG;
    }
    *ppv = std::ptr::null_mut();

    let rclsid = &*rclsid;
    let riid = &*riid;

    if *rclsid != CLSID_IPA_TIP {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    let factory: IClassFactory = IpaClassFactory.into();
    factory.query(riid, ppv)
}

/// Returns S_OK if the DLL can be safely unloaded (no outstanding COM objects).
#[cfg(windows)]
#[no_mangle]
extern "system" fn DllCanUnloadNow() -> HRESULT {
    if DLL_REF_COUNT.load(Ordering::SeqCst) == 0 {
        S_OK
    } else {
        S_FALSE
    }
}

/// Self-registration — called by `regsvr32 ipa_ime.dll`.
#[cfg(windows)]
#[no_mangle]
unsafe extern "system" fn DllRegisterServer() -> HRESULT {
    match register::register_tip(DLL_INSTANCE) {
        Ok(()) => S_OK,
        Err(e) => e.code(),
    }
}

/// Self-unregistration — called by `regsvr32 /u ipa_ime.dll`.
#[cfg(windows)]
#[no_mangle]
unsafe extern "system" fn DllUnregisterServer() -> HRESULT {
    match register::unregister_tip() {
        Ok(()) => S_OK,
        Err(e) => e.code(),
    }
}

// --- COM Class Factory ---

#[cfg(windows)]
#[implement(IClassFactory)]
struct IpaClassFactory;

#[cfg(windows)]
impl IClassFactory_Impl for IpaClassFactory_Impl {
    fn CreateInstance(
        &self,
        _punkouter: Option<&IUnknown>,
        riid: *const GUID,
        ppvobject: *mut *mut std::ffi::c_void,
    ) -> Result<()> {
        unsafe {
            if ppvobject.is_null() {
                return Err(Error::from(E_INVALIDARG));
            }
            *ppvobject = std::ptr::null_mut();

            let tip: ITfTextInputProcessor = IpaTextInputProcessor::new().into();
            tip.query(&*riid, ppvobject)
        }
    }

    fn LockServer(&self, flock: BOOL) -> Result<()> {
        if flock.as_bool() {
            dll_add_ref();
        } else {
            dll_release();
        }
        Ok(())
    }
}
