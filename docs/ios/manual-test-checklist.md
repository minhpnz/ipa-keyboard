# iOS Manual Test Checklist

Re-run every release. Things automation can't reliably catch.

## Install + enable
- [ ] Clean install → Setup tab shows → tap "Open Settings" → Settings opens
- [ ] Add IPA Keyboard via Settings → General → Keyboard → Keyboards → Add New Keyboard
- [ ] Open IPAKeyboardApp; tap "I've done this"; relaunch; app opens to Reference tab

## Typing in real apps
For each: Messages, Notes, Safari URL bar, Safari web form, Mail, WhatsApp, Discord, Twitter, Google Docs

- [ ] Switch to IPA Keyboard via globe
- [ ] Type plain letters (q, w, e, r, t, y) — all insert correctly
- [ ] Long-press `a` → popover appears — drag to `æ` — release — `æ` inserted
- [ ] Long-press every dotted letter at least once across the session, insert at least one variant per letter
- [ ] Backspace deletes multi-codepoint variants like `dʒ` or `ɑː` correctly (one tap = one visual character gone)
- [ ] Globe-switch mid-typing to system keyboard and back — no stuck popover

## Third-party-keyboard coexistence stress
- [ ] Install ≥2 other third-party keyboards (Gboard, SwiftKey)
- [ ] Start long-press on a dotted key; while popover visible, rapidly globe-cycle 5+ times → no crash, no stuck popover, no phantom insertion
- [ ] Return to IPA Keyboard and start a fresh long-press → works

## Device coverage
- [ ] Physical iPhone SE (compact width / small keys)
- [ ] Physical iPad in portrait, landscape, split-keyboard, floating-keyboard modes

## Accessibility
- [ ] VoiceOver: each IPA variant announced with its name from LocalizedSymbolNames
- [ ] Dynamic Type at AX3: container app scales; keyboard key sizes unchanged
- [ ] Low Power Mode ON → haptics no-op gracefully; no visible glitch

## Edge cases
- [ ] Memory soak: 10-minute continuous typing session, no crash, no perceptible lag
- [ ] ASCII-capable contexts: login form, plain UITextField — keyboard IS offered
- [ ] Password fields — keyboard is NOT offered (iOS enforces this regardless)
- [ ] Rotate mid-long-press → popover dismissed cleanly
