//! ITfTextInputProcessor — the main entry point for the TSF TIP.

use std::cell::RefCell;
use std::sync::atomic::{AtomicBool, Ordering};

use windows::core::*;
use windows::Win32::UI::TextServices::*;

use ipa_mapping_engine::MappingEngine;

use crate::composition::CompositionManager;
use crate::config_reader;
use crate::key_handler;
use crate::{dll_add_ref, dll_release, GUID_IPA_PROFILE};

/// Internal mutable state of the TIP, behind a RefCell for interior mutability.
pub struct TipState {
    pub thread_mgr: ITfThreadMgr,
    pub client_id: u32,
    pub engine: MappingEngine,
    pub composition: CompositionManager,
    pub ipa_mode: bool,
    keystroke_mgr_cookie: u32,
}

/// The IPA Text Input Processor COM object.
#[implement(
    ITfTextInputProcessor,
    ITfTextInputProcessorEx,
    ITfKeyEventSink,
    ITfCompositionSink,
    ITfDisplayAttributeProvider,
)]
pub struct IpaTextInputProcessor {
    state: RefCell<Option<TipState>>,
    activated: AtomicBool,
}

impl IpaTextInputProcessor {
    pub fn new() -> Self {
        dll_add_ref();
        Self {
            state: RefCell::new(None),
            activated: AtomicBool::new(false),
        }
    }

    pub fn with_state<F, R>(&self, f: F) -> Result<R>
    where
        F: FnOnce(&mut TipState) -> Result<R>,
    {
        let mut borrow = self.state.borrow_mut();
        match borrow.as_mut() {
            Some(state) => f(state),
            None => Err(Error::from(E_UNEXPECTED)),
        }
    }
}

impl Drop for IpaTextInputProcessor {
    fn drop(&mut self) {
        dll_release();
    }
}

impl ITfTextInputProcessor_Impl for IpaTextInputProcessor_Impl {
    fn Activate(&self, ptim: Option<&ITfThreadMgr>, tid: u32) -> Result<()> {
        let thread_mgr = ptim.ok_or(Error::from(E_INVALIDARG))?.clone();

        // Load config
        let config = config_reader::load_config();
        let engine = MappingEngine::new(config);

        let composition = CompositionManager::new();

        let mut state = TipState {
            thread_mgr: thread_mgr.clone(),
            client_id: tid,
            engine,
            composition,
            ipa_mode: true,
            keystroke_mgr_cookie: 0,
        };

        // Register as key event sink
        unsafe {
            let keystroke_mgr: ITfKeystrokeMgr = thread_mgr.cast()?;
            let this_sink: ITfKeyEventSink = self.cast()?;
            keystroke_mgr.AdviseKeyEventSink(tid, &this_sink, TRUE)?;
        }

        // Register Ctrl+Space as a preserved key for mode toggle
        key_handler::register_preserved_keys(&thread_mgr, tid)?;

        self.this.state.replace(Some(state));
        self.this.activated.store(true, Ordering::SeqCst);

        Ok(())
    }

    fn Deactivate(&self) -> Result<()> {
        if let Some(state) = self.this.state.borrow_mut().take() {
            unsafe {
                // Unadvise key event sink
                let keystroke_mgr: ITfKeystrokeMgr = state.thread_mgr.cast()?;
                keystroke_mgr.UnadviseKeyEventSink(state.client_id)?;

                // Unregister preserved keys
                key_handler::unregister_preserved_keys(&state.thread_mgr, state.client_id)?;
            }
        }
        self.this.activated.store(false, Ordering::SeqCst);
        Ok(())
    }
}

impl ITfTextInputProcessorEx_Impl for IpaTextInputProcessor_Impl {
    fn ActivateEx(&self, ptim: Option<&ITfThreadMgr>, tid: u32, _dwflags: u32) -> Result<()> {
        self.Activate(ptim, tid)
    }
}

// Display attribute provider — minimal stub required for registration
impl ITfDisplayAttributeProvider_Impl for IpaTextInputProcessor_Impl {
    fn EnumDisplayAttributeInfo(&self) -> Result<IEnumTfDisplayAttributeInfo> {
        Err(Error::from(E_NOTIMPL))
    }

    fn GetDisplayAttributeInfo(
        &self,
        _guid: *const GUID,
    ) -> Result<ITfDisplayAttributeInfo> {
        Err(Error::from(E_NOTIMPL))
    }
}
