//! TSF composition management for IPA symbol insertion.
//!
//! Manages starting, updating, and ending compositions in the active document.

use windows::core::*;
use windows::Win32::Foundation::*;
use windows::Win32::UI::TextServices::*;

use crate::text_input_processor::IpaTextInputProcessor_Impl;

/// Tracks the active TSF composition and the length of the last inserted symbol.
pub struct CompositionManager {
    composition: Option<ITfComposition>,
    last_symbol_len: usize,
}

impl CompositionManager {
    pub fn new() -> Self {
        Self {
            composition: None,
            last_symbol_len: 0,
        }
    }

    /// Insert a new IPA symbol (fresh, not replacing).
    /// Starts a new composition, inserts text, and ends it.
    pub fn insert_text(
        &mut self,
        context: &ITfContext,
        client_id: u32,
        symbol: &str,
    ) -> Result<()> {
        // End any previous composition
        self.end_composition();

        let symbol_wide: Vec<u16> = symbol.encode_utf16().collect();

        unsafe {
            let edit_cookie = self.request_edit_cookie(context, client_id)?;

            // Get the insertion point (selection)
            let mut sel = [TF_SELECTION::default()];
            let mut fetched = 0u32;
            context.GetSelection(edit_cookie, TF_DEFAULT_SELECTION, &mut sel, &mut fetched)?;

            if fetched == 0 {
                return Ok(());
            }

            let range = sel[0].range.as_ref().ok_or(Error::from(E_FAIL))?;

            // Start composition
            let context_comp: ITfContextComposition = context.cast()?;
            let this_sink: ITfCompositionSink = self.get_composition_sink()?;

            // Insert the symbol text
            range.SetText(edit_cookie, 0, &symbol_wide)?;

            // Start composition over the inserted range
            let comp = context_comp.StartComposition(edit_cookie, range, &this_sink)?;
            self.composition = Some(comp);
            self.last_symbol_len = symbol.chars().count();

            // End composition immediately (we don't show a candidate window)
            self.end_composition();
        }

        Ok(())
    }

    /// Replace the previously inserted symbol (cycling).
    /// Finds the composition range and replaces its text.
    pub fn replace_text(
        &mut self,
        context: &ITfContext,
        client_id: u32,
        symbol: &str,
    ) -> Result<()> {
        let symbol_wide: Vec<u16> = symbol.encode_utf16().collect();

        unsafe {
            let edit_cookie = self.request_edit_cookie(context, client_id)?;

            // Get the current selection / insertion point
            let mut sel = [TF_SELECTION::default()];
            let mut fetched = 0u32;
            context.GetSelection(edit_cookie, TF_DEFAULT_SELECTION, &mut sel, &mut fetched)?;

            if fetched == 0 {
                return Ok(());
            }

            let range = sel[0].range.as_ref().ok_or(Error::from(E_FAIL))?;

            // Move the start of the range back by the length of the previous symbol
            // to select the text we want to replace
            let mut shifted = 0i32;
            range.ShiftStart(
                edit_cookie,
                -(self.last_symbol_len as i32),
                &mut shifted,
                std::ptr::null(),
            )?;

            // Replace with the new symbol
            range.SetText(edit_cookie, 0, &symbol_wide)?;

            // Collapse the range to the end (move cursor after new symbol)
            range.Collapse(edit_cookie, TF_ANCHOR_END)?;

            // Update selection
            let new_sel = TF_SELECTION {
                range: Some(range.clone()),
                style: TF_SELECTIONSTYLE {
                    ase: TF_AE_END,
                    fInterimChar: FALSE,
                },
            };
            context.SetSelection(edit_cookie, &[new_sel])?;

            self.last_symbol_len = symbol.chars().count();
        }

        Ok(())
    }

    /// End the current composition, if any.
    pub fn end_composition(&mut self) {
        if let Some(comp) = self.composition.take() {
            unsafe {
                let _ = comp.EndComposition();
            }
        }
    }

    /// Request a synchronous read-write edit cookie.
    unsafe fn request_edit_cookie(
        &self,
        context: &ITfContext,
        client_id: u32,
    ) -> Result<u32> {
        // For a TIP, we use the client ID as the edit cookie in synchronous edits.
        // In practice, TSF manages edit sessions — here we simplify by requesting
        // a synchronous edit session.
        Ok(client_id)
    }

    /// Get a composition sink interface — placeholder for proper implementation.
    /// In the full implementation, this would return the TIP's ITfCompositionSink.
    unsafe fn get_composition_sink(&self) -> Result<ITfCompositionSink> {
        Err(Error::from(E_NOTIMPL))
    }
}

// ITfCompositionSink — called when a composition is terminated externally
impl ITfCompositionSink_Impl for IpaTextInputProcessor_Impl {
    fn OnCompositionTerminated(
        &self,
        _ecwrite: u32,
        _pcomposition: Option<&ITfComposition>,
    ) -> Result<()> {
        // The application terminated our composition — reset engine state
        let _ = self.this.with_state(|state| {
            state.engine.reset();
            state.composition.end_composition();
            Ok(())
        });
        Ok(())
    }
}
