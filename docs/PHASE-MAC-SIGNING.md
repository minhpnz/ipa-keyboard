# Phase M — Mac Distribution Readiness (Sign + Notarize)

**Trigger:** Apple Developer Program membership is now active.
**Goal:** Replace the unsigned `package-release/IPA_Keyboard_0.1.0_universal.dmg` (which currently requires `xattr -cr` to bypass Gatekeeper) with a signed + notarized DMG that installs cleanly via drag-and-drop.
**Out of scope:** Mac App Store submission — see `MAC-APP-STORE-GUIDE.md`. Tracked separately because sandboxing is incompatible with CGEvent taps.

---

## Why this phase exists

The 0.1.0 DMG was shipped unsigned. `package-release/INSTALL.txt` walks users through three Gatekeeper-bypass methods, including a Terminal command (`xattr -cr`). That's a real adoption barrier, and on macOS 15+ several of the workarounds no longer work.

Now that we have an Apple Developer membership, the proper fix is straightforward — the technical mechanics are already documented in `DISTRIBUTION.md` and partially scripted in `scripts/notarize-macos.sh`. This phase wires it all together and ships a clean DMG.

## What's already in place

| Asset | Status |
|---|---|
| `docs/DISTRIBUTION.md` | Full inside-out signing + notarization commands |
| `scripts/notarize-macos.sh` | Production-ready: notarytool submit, wait, staple, verify, Gatekeeper assess |
| `scripts/build-release.sh` | Universal Tauri build + DMG creation **(currently unsigned)** |
| `companion-app/src-tauri/Entitlements.plist` | JIT + library-validation entitlements set |
| `companion-app/src-tauri/tauri.conf.json` | `hardenedRuntime: true`, `signingIdentity: null` (placeholder) |
| `ime-core/macos/Resources/IPAKeyboard.entitlements` | Daemon entitlements (CGEvent tap friendly) |

## What's missing (the work)

### M.1 — One-time Apple Developer account setup (human steps)

- [ ] **Developer ID Application certificate**
  - Keychain Access → *Certificate Assistant* → *Request a Certificate from a Certificate Authority* → "Saved to disk" → save CSR
  - developer.apple.com → Certificates → **+** → *Developer ID Application* → upload CSR → download `.cer` → double-click to install in login keychain
  - Verify: `security find-identity -v -p codesigning` lists `Developer ID Application: <Name> (TEAM_ID)`
  - **Capture:** the exact Common Name string (use as `APPLE_SIGNING_IDENTITY`) and the Team ID

- [ ] **App Store Connect API key for notarytool**
  - appstoreconnect.apple.com → *Users and Access* → *Integrations* → *Keys* → **+**
  - Role: *Developer* (sufficient for notarytool — does not need full Admin)
  - Download the `.p8` file (**one-time only** — Apple will not let you re-download)
  - **Capture:** Key ID and Issuer ID (UUID)
  - Store the `.p8` somewhere local-only — e.g. `~/.appstore-connect/AuthKey_<KeyID>.p8`. **Never commit.**

- [ ] **Auth dry-run**
  - `xcrun notarytool history --key <path-to-p8> --key-id <KeyID> --issuer <IssuerUUID>` should succeed (empty history is fine)
  - This catches credential mistakes before a 30-minute submission attempt fails on auth

### M.2 — Wire signing into `build-release.sh`

**Architecture note (verified 2026-04-29):** the `ipa-keyboard-daemon` crate is a **Rust dependency of the Tauri app** (`Cargo.toml: ipa-keyboard-daemon = { path = "../../ime-core/macos" }`), statically linked into the main `ipa-keyboard` binary. The bundle layout is:

```
IPA Keyboard.app/
  Contents/
    Info.plist
    MacOS/ipa-keyboard          # single executable, daemon code linked in
    Resources/...
```

There is no `Frameworks/` directory and no sidecar — so the inside-out signing sequence from `DISTRIBUTION.md` does **not** apply here. A single `codesign` on the bundle is sufficient.

The script currently builds the universal `.app` and goes straight to DMG creation, leaving the bundle unsigned. Add a signing block between the build and DMG steps.

Required changes:

- Read `APPLE_SIGNING_IDENTITY` from env. If unset, log a clear warning and skip signing (preserving local dev workflow); if set, sign the bundle:

  ```
  codesign --force --options runtime \
           --entitlements companion-app/src-tauri/Entitlements.plist \
           --sign "$APPLE_SIGNING_IDENTITY" --timestamp \
           "$APP_PATH"
  ```

  Use `companion-app/src-tauri/Entitlements.plist` (the Tauri app entitlements — JIT for WKWebView and library-validation disable for plugin dylibs). The `ime-core/macos/Resources/IPAKeyboard.entitlements` file is for a **separate** component (the standalone IMK input method) and must not be used here.
- Gate before continuing: `codesign --verify --deep --strict "$APP"` must pass; `spctl --assess --type execute "$APP"` should be "accepted" (or "rejected, source=Unnotarized" — that's expected pre-notarization, not a failure).
- Mirror the identity into `tauri.conf.json` is **not** needed; signing post-build in the script is simpler and more transparent.

### M.3 — Insert notarization step before DMG creation

Current order: build → DMG. Required order: build → sign → notarize → staple → DMG → notarize DMG → staple DMG.

Approach: extend `build-release.sh` to call `scripts/notarize-macos.sh "$APP"` after signing, then create DMG, then call `notarize-macos.sh "$DMG"`. The script already handles staple + verify in both cases.

Required env vars at release time:

```
APPLE_SIGNING_IDENTITY="Developer ID Application: <Name> (TEAM_ID)"
NOTARIZE_API_KEY_ID="..."
NOTARIZE_API_KEY_ISSUER="..."
NOTARIZE_API_KEY_PATH="$HOME/.appstore-connect/AuthKey_<id>.p8"
```

Add an `--unsigned` (or `--dev`) flag for local builds that skips both signing and notarization.

### M.4 — Rewrite `INSTALL.txt`

Both `package-release/INSTALL.txt` and the heredoc inside `scripts/build-release.sh` document the unsigned-app workaround. After this phase, both should be replaced with:

```
1. Open the DMG
2. Drag "IPA Keyboard.app" to Applications
3. Double-click to open
4. Grant Accessibility permission when prompted
   (System Settings → Privacy & Security → Accessibility → enable IPA Keyboard)
5. Use Ctrl+Space to toggle, Ctrl+letter to cycle IPA variants
```

No Terminal commands. No right-click → Open. No "Open Anyway" in System Settings.

### M.5 — Remove `fix-gatekeeper.command`

`package-release/fix-gatekeeper.command` only exists to work around the unsigned DMG. With notarization in place it serves no purpose — delete it from the repo and from any future DMG.

### M.6 — Replace the released DMG

- Bump version: `0.1.0` → `0.1.1` (cleaner trail than overwriting). Per `DISTRIBUTION.md`'s version-bumping table:
  - `companion-app/src-tauri/tauri.conf.json` → `version`
  - `companion-app/src-tauri/Cargo.toml` → `version`
  - `companion-app/package.json` → `version`
  - `ime-core/macos/Resources/Info.plist` → `CFBundleShortVersionString`, `CFBundleVersion`
  - `ime-core/shared/Cargo.toml` → `version`
  - `ime-core/macos/Cargo.toml` → `version`
- Run the new pipeline end-to-end with the env vars from M.3
- Replace `package-release/IPA_Keyboard_0.1.0_universal.dmg` with `IPA_Keyboard_0.1.1_universal.dmg`

### M.7 — Verification on a clean state

Either on a second Mac, or after deleting the prior install + clearing quarantine cache (`sudo xattr -dr com.apple.quarantine /Applications/IPA\ Keyboard.app` is **not** what we want here — instead delete the app entirely and re-mount the new DMG fresh).

Required outcomes:

- Mount DMG → drag to `/Applications` → double-click → app opens with **no Gatekeeper dialog**
- `spctl --assess --type execute --verbose=2 /Applications/IPA\ Keyboard.app` returns:
  ```
  accepted
  source=Notarized Developer ID
  ```
- `xcrun stapler validate /Applications/IPA\ Keyboard.app` succeeds
- Daemon launches; Accessibility prompt appears; Ctrl+Space toggles input mode; Ctrl+letter cycles variants

## Exit criteria

- [ ] Signed + notarized `IPA_Keyboard_0.1.1_universal.dmg` in `package-release/`
- [ ] No `xattr -cr` instructions anywhere in shipped materials or build scripts
- [ ] `fix-gatekeeper.command` removed
- [ ] `build-release.sh` produces a release-ready DMG in one command (given env vars set), with an `--unsigned` flag for dev
- [ ] Clean-state verification passes on a Mac that has never run the app before
- [ ] Branch merged to main

## After this phase

Resume iOS Phase 3:
- Task 3.4 — popover snapshot tests on corner keys
- Task 3.5 — gesture cancellation on VC lifecycle
- Phase 3 exit checklist + finishing-a-development-branch

## Deferred: Mac App Store track

`docs/MAC-APP-STORE-GUIDE.md` covers the App Store path. Sandboxing is required there, and CGEvent taps are not sandbox-compatible — so that track likely needs an architecture rethink (XPC helper, sandbox-compatible permission flow, or a feature subset) before it's executable. Not blocking for direct-download distribution.
