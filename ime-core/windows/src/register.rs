//! COM and TSF registration for the IPA Keyboard TIP.
//!
//! Called by `DllRegisterServer` / `DllUnregisterServer` (via regsvr32).
//! Registers the COM class and the TSF language profile.

use windows::core::*;
use windows::Win32::Foundation::*;
use windows::Win32::System::Com::*;
use windows::Win32::UI::TextServices::*;

use crate::{CLSID_IPA_TIP, GUID_IPA_PROFILE};

/// Display name shown in Windows language settings.
const TIP_DISPLAY_NAME: &str = "IPA Keyboard";

/// Language ID — English (US) as the base language.
const LANGID_EN_US: u16 = 0x0409;

/// Register the TIP as a COM server and TSF input processor.
pub unsafe fn register_tip(hmodule: HMODULE) -> Result<()> {
    // Step 1: Register COM class in the registry
    register_com_server(hmodule)?;

    // Step 2: Register as a TSF input processor with a language profile
    let profiles: ITfInputProcessorProfiles =
        CoCreateInstance(&CLSID_TF_InputProcessorProfiles, None, CLSCTX_INPROC_SERVER)?;

    profiles.Register(&CLSID_IPA_TIP)?;

    let display_name: Vec<u16> = TIP_DISPLAY_NAME.encode_utf16().chain(Some(0)).collect();

    profiles.AddLanguageProfile(
        &CLSID_IPA_TIP,
        LANGID_EN_US,
        &GUID_IPA_PROFILE,
        &display_name,
        display_name.len() as u32,
        &[], // icon file path (empty = no icon file)
        0,
        0, // icon index
    )?;

    // Step 3: Register the categories this TIP supports
    let cat_mgr: ITfCategoryMgr =
        CoCreateInstance(&CLSID_TF_CategoryMgr, None, CLSCTX_INPROC_SERVER)?;

    // Register as a TIP
    cat_mgr.RegisterCategory(
        &CLSID_IPA_TIP,
        &GUID_TFCAT_TIP_KEYBOARD,
        &CLSID_IPA_TIP,
    )?;

    Ok(())
}

/// Unregister the TIP.
pub unsafe fn unregister_tip() -> Result<()> {
    // Unregister TSF profile
    let profiles: ITfInputProcessorProfiles =
        CoCreateInstance(&CLSID_TF_InputProcessorProfiles, None, CLSCTX_INPROC_SERVER)?;

    let _ = profiles.Unregister(&CLSID_IPA_TIP);

    // Unregister category
    let cat_mgr: ITfCategoryMgr =
        CoCreateInstance(&CLSID_TF_CategoryMgr, None, CLSCTX_INPROC_SERVER)?;

    let _ = cat_mgr.UnregisterCategory(
        &CLSID_IPA_TIP,
        &GUID_TFCAT_TIP_KEYBOARD,
        &CLSID_IPA_TIP,
    );

    // Remove COM registration
    unregister_com_server()?;

    Ok(())
}

/// Register the DLL as a COM in-process server in the registry.
unsafe fn register_com_server(hmodule: HMODULE) -> Result<()> {
    use windows::Win32::System::LibraryLoader::GetModuleFileNameW;

    // Get DLL path
    let mut path_buf = [0u16; 260];
    let len = GetModuleFileNameW(hmodule, &mut path_buf);
    if len == 0 {
        return Err(Error::from(E_FAIL));
    }
    let dll_path = String::from_utf16_lossy(&path_buf[..len as usize]);

    // Write to HKCU to avoid requiring admin rights.
    // HKCU\Software\Classes\CLSID\{guid}\InprocServer32
    let clsid_str = format!("{{{:?}}}", CLSID_IPA_TIP);
    let key_path = format!(
        "Software\\Classes\\CLSID\\{}\\InprocServer32",
        clsid_str
    );

    // Use RegCreateKeyExW / RegSetValueExW via the windows crate
    use windows::Win32::System::Registry::*;

    let key_path_wide: Vec<u16> = key_path.encode_utf16().chain(Some(0)).collect();
    let mut hkey = HKEY::default();
    let mut disposition = 0u32;

    RegCreateKeyExW(
        HKEY_CURRENT_USER,
        PCWSTR(key_path_wide.as_ptr()),
        0,
        None,
        REG_OPTION_NON_VOLATILE,
        KEY_WRITE,
        None,
        &mut hkey,
        Some(&mut disposition),
    )?;

    // Set default value to DLL path
    let dll_path_wide: Vec<u16> = dll_path.encode_utf16().chain(Some(0)).collect();
    RegSetValueExW(
        hkey,
        None,
        0,
        REG_SZ,
        Some(std::slice::from_raw_parts(
            dll_path_wide.as_ptr() as *const u8,
            dll_path_wide.len() * 2,
        )),
    )?;

    // Set ThreadingModel = Apartment
    let threading_model: Vec<u16> = "ThreadingModel\0".encode_utf16().collect();
    let apartment: Vec<u16> = "Apartment\0".encode_utf16().collect();
    RegSetValueExW(
        hkey,
        PCWSTR(threading_model.as_ptr()),
        0,
        REG_SZ,
        Some(std::slice::from_raw_parts(
            apartment.as_ptr() as *const u8,
            apartment.len() * 2,
        )),
    )?;

    RegCloseKey(hkey)?;

    Ok(())
}

/// Remove the COM registration from the registry.
unsafe fn unregister_com_server() -> Result<()> {
    use windows::Win32::System::Registry::*;

    let clsid_str = format!("{{{:?}}}", CLSID_IPA_TIP);
    let key_path = format!("Software\\Classes\\CLSID\\{}", clsid_str);
    let key_path_wide: Vec<u16> = key_path.encode_utf16().chain(Some(0)).collect();

    // Delete the InprocServer32 subkey first, then the CLSID key
    let subkey_path = format!("{}\\InprocServer32", key_path);
    let subkey_wide: Vec<u16> = subkey_path.encode_utf16().chain(Some(0)).collect();
    let _ = RegDeleteKeyW(HKEY_CURRENT_USER, PCWSTR(subkey_wide.as_ptr()));
    let _ = RegDeleteKeyW(HKEY_CURRENT_USER, PCWSTR(key_path_wide.as_ptr()));

    Ok(())
}
