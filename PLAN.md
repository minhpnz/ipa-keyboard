# IPA Keyboard — Design Plan

## Status: IN PROGRESS (Phase 5 — Mac App Store Submission)

---

## 1. Understanding Summary

### What
- System-wide IPA Input Method Editor + companion Tauri app
- IME works in all apps (Chrome, Word, VSCode, etc.)
- Companion app provides visual keyboard, settings, document management

### Why
- Desktop alternative to web-based tools like TypeIt.org
- System-wide input (not limited to one app window)
- Trusted native app that passes Windows Defender + macOS Gatekeeper

### Who
- Linguistics students, professional linguists, language learners
- Progressive disclosure: simple by default, full IPA chart accessible

### Non-Goals
- No candidate dropdown selection (v1) — direct cycling only
- No cloud sync, no user accounts
- Not a browser extension

---

## 2. Project Structure

```
ipa-keyboard/
├── ime-core/
│   ├── windows/                # TSF IME (Rust + COM)
│   │   ├── Cargo.toml
│   │   ├── src/
│   │   │   ├── lib.rs          # TIP entry point
│   │   │   ├── key_handler.rs
│   │   │   ├── composition.rs
│   │   │   ├── mapping_engine.rs
│   │   │   └── config_reader.rs
│   │   └── register.ps1        # COM registration script
│   │
│   ├── macos/                  # IMK IME (Swift)
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   ├── IPAInputController.swift
│   │   │   ├── KeyHandler.swift
│   │   │   ├── MappingEngine.swift
│   │   │   └── ConfigReader.swift
│   │   └── Info.plist
│   │
│   └── shared/                 # Shared logic (Rust lib)
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           ├── symbols.rs      # IPA symbol dataset
│           ├── cycle_engine.rs # Ctrl+key cycling logic
│           └── mapping.rs      # Key → symbol mapping
│
├── companion-app/              # Tauri + React
│   ├── src-tauri/
│   │   ├── Cargo.toml
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── commands.rs     # Tauri commands
│   │   │   ├── storage.rs      # Document save/load
│   │   │   └── config.rs       # Shared config read/write
│   │   └── tauri.conf.json
│   │
│   ├── src/                    # React frontend
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── VirtualKeyboard.tsx
│   │   │   ├── SymbolGroup.tsx
│   │   │   ├── TextEditor.tsx
│   │   │   ├── Toolbar.tsx
│   │   │   ├── SymbolSearch.tsx
│   │   │   └── Favorites.tsx
│   │   ├── data/
│   │   │   └── ipa-symbols.json
│   │   ├── hooks/
│   │   │   ├── useSymbolCycle.ts
│   │   │   └── useFrequencyTracker.ts
│   │   └── styles/
│   │       └── keyboard.css
│   │
│   └── package.json
│
├── shared-config/              # Config schema + defaults
│   ├── default-mappings.json
│   └── config-schema.json
│
├── scripts/
│   ├── build-windows.ps1
│   ├── build-macos.sh
│   ├── sign-windows.ps1
│   └── sign-macos.sh
│
├── CLAUDE.md
├── PLAN.md
└── README.md
```

---

## 3. Component Design

### 3.1 Mapping Engine (shared Rust crate)

The mapping engine is the core logic shared between both IME implementations.

```rust
// shared/src/mapping.rs

use std::collections::HashMap;

pub struct MappingEngine {
    /// Key letter → list of IPA symbols to cycle through
    cycle_map: HashMap<char, Vec<String>>,
    /// Current cycle index per key
    cycle_state: HashMap<char, usize>,
    /// Timestamp of last keypress per key (for cycle timeout)
    last_press: HashMap<char, std::time::Instant>,
    /// Cycle timeout in milliseconds (reset after this)
    cycle_timeout_ms: u64,
}

impl MappingEngine {
    pub fn new(mappings: HashMap<char, Vec<String>>, timeout_ms: u64) -> Self {
        Self {
            cycle_map: mappings,
            cycle_state: HashMap::new(),
            last_press: HashMap::new(),
            cycle_timeout_ms: timeout_ms,
        }
    }

    /// Called when Ctrl+key is pressed. Returns the next IPA symbol.
    pub fn cycle_next(&mut self, key: char) -> Option<&str> {
        let symbols = self.cycle_map.get(&key)?;
        let now = std::time::Instant::now();

        // Reset cycle if timeout elapsed
        let index = if let Some(last) = self.last_press.get(&key) {
            if now.duration_since(*last).as_millis() as u64 > self.cycle_timeout_ms {
                0
            } else {
                let prev = self.cycle_state.get(&key).copied().unwrap_or(0);
                (prev + 1) % symbols.len()
            }
        } else {
            0
        };

        self.cycle_state.insert(key, index);
        self.last_press.insert(key, now);
        Some(&symbols[index])
    }

    /// Reset cycle state for a key
    pub fn reset(&mut self, key: char) {
        self.cycle_state.remove(&key);
        self.last_press.remove(&key);
    }

    /// Load mappings from JSON config
    pub fn load_from_json(json_str: &str, timeout_ms: u64) -> Result<Self, serde_json::Error> {
        let mappings: HashMap<char, Vec<String>> = serde_json::from_str(json_str)?;
        Ok(Self::new(mappings, timeout_ms))
    }
}
```

### 3.2 Default Mappings (shared-config/default-mappings.json)

```json
{
  "a": ["ɑ", "æ", "ɐ", "ʌ", "ã"],
  "b": ["β", "ɓ", "ʙ"],
  "c": ["ç", "ɕ"],
  "d": ["ð", "d͡ʒ", "ɖ", "ɗ"],
  "e": ["ə", "ɚ", "ɵ"],
  "g": ["ɡ", "ɠ"],
  "h": ["ħ", "ɦ", "ɥ", "ɧ", "ɦ"],
  "i": ["ɪ", "ɨ", "ɯ"],
  "j": ["ʝ", "ɟ"],
  "l": ["ɬ", "ɮ", "ɭ", "ɫ"],
  "m": ["ɱ"],
  "n": ["ŋ", "ɲ", "ɳ", "ɴ"],
  "o": ["ɔ", "œ", "ɒ", "õ"],
  "p": ["ɸ"],
  "r": ["ɾ", "ɹ", "ʀ", "ɻ", "ɽ"],
  "s": ["ʃ", "ʂ"],
  "t": ["θ", "t͡ʃ", "t͡s", "ʈ"],
  "u": ["ʊ", "ʉ"],
  "v": ["ʌ", "ʋ"],
  "w": ["ʍ", "ɯ"],
  "x": ["χ"],
  "y": ["ɣ", "ʎ", "ʏ", "ɤ"],
  "z": ["ʒ", "ʐ", "ʑ"]
}
```

### 3.3 IPA Symbol Dataset (companion-app/src/data/ipa-symbols.json)

```json
{
  "consonants": {
    "A": { "trigger": "a", "symbols": ["ɑ", "æ", "ɐ", "ʌ", "ã"] },
    "B": { "trigger": "b", "symbols": ["β", "ɓ", "ʙ"] },
    "C": { "trigger": "c", "symbols": ["ç", "ɕ"] },
    ...
  },
  "vowels": { ... },
  "diacritics": {
    "tones": ["˥", "˦", "˧", "˨", "˩"],
    "length": ["ː", "ˑ"],
    "stress": ["ˈ", "ˌ"],
    "nasalization": ["̃"],
    "aspiration": ["ʰ"],
    ...
  },
  "suprasegmentals": {
    "boundaries": ["|", "‖", "∅", "→"],
    "linking": ["‿"],
    ...
  }
}
```

### 3.4 Windows IME — TSF Implementation (Rust + COM)

```
ime-core/windows/src/
├── lib.rs              # DLL entry point, COM class factory
├── key_handler.rs      # ITfKeyEventSink — intercept Ctrl+key
├── composition.rs      # ITfCompositionSink — manage text insertion
├── mapping_engine.rs   # Wraps shared::MappingEngine
└── config_reader.rs    # Reads shared-config JSON from AppData
```

Key interfaces to implement:
- `ITfTextInputProcessor` — entry point, lifecycle
- `ITfKeyEventSink` — `OnKeyDown()`, `OnKeyUp()`
- `ITfCompositionSink` — `StartComposition()`, `EndComposition()`
- `ITfThreadMgrEventSink` — thread focus events

Registration:
- Build as DLL
- Register COM component via `regsvr32`
- Add to Windows IME registry keys

### 3.5 macOS IME — InputMethodKit (Swift)

```
ime-core/macos/Sources/
├── IPAInputController.swift   # IMKInputController subclass
├── KeyHandler.swift           # handleEvent → intercept keys
├── MappingEngine.swift        # FFI bridge to shared Rust crate
└── ConfigReader.swift         # Read config from ~/Library/Application Support/
```

Key methods:
- `handleEvent(_ event: NSEvent)` — intercept keystrokes
- `insertText(_ string: Any)` — commit IPA symbol
- `setMarkedText(_ string: Any)` — composition preview (v2)

Bundle requirements:
- `.app` bundle with IME extension
- `Info.plist` with `InputMethodConnectionName`, `InputMethodServerControllerClass`
- Register in System Settings → Keyboard → Input Sources

### 3.6 Companion App — React Components

```
VirtualKeyboard.tsx
├── SymbolGroup (letter="A")
│   ├── TriggerButton (shows "A", highlighted)
│   └── SymbolButton × N (ɑ, æ, ɐ, ʌ, ã)
├── SymbolGroup (letter="B")
│   └── ...
├── DiacriticsRow
│   ├── ToneMarks
│   ├── LengthMarks
│   └── StressMarks
└── SuprasegmentalRow
```

**TextEditor.tsx** — Rich text area (B/I/U formatting for display, saves as plain .txt)
**Toolbar.tsx** — B, I, U, S, s, R buttons + Undo/Redo + Clear + Copy All
**SymbolSearch.tsx** — Search by name ("voiced bilabial fricative" → β)
**Favorites.tsx** — Pinned frequently-used symbols

### 3.7 IPC Between IME and Companion App

Shared config file at:
- **Windows**: `%APPDATA%/ipa-keyboard/config.json`
- **macOS**: `~/Library/Application Support/ipa-keyboard/config.json`

```json
{
  "version": 1,
  "mappings": { ... },
  "favorites": ["ə", "ʃ", "θ", "ŋ"],
  "cycle_timeout_ms": 800,
  "ime_enabled": true
}
```

Both IME and companion app read this file. Companion app writes changes. IME watches for file changes (via OS file watcher) and reloads.

---

## 4. Build & Signing

### 4.1 Windows Build

```powershell
# Build IME DLL
cd ime-core/windows
cargo build --release
# Output: target/release/ipa_ime.dll

# Build companion app
cd companion-app
npm install
npm run tauri build
# Output: src-tauri/target/release/bundle/msi/IPA-Keyboard_1.0.0_x64.msi
```

**Windows Signing:**
1. Obtain EV Code Signing Certificate (DigiCert, Sectigo, etc.)
2. Sign DLL: `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a ipa_ime.dll`
3. Sign MSI: `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a IPA-Keyboard.msi`
4. Register DLL: `regsvr32 ipa_ime.dll`

### 4.2 macOS Build

```bash
# Build IME bundle
cd ime-core/macos
swift build -c release
# Package as .app with IME extension

# Build companion app
cd companion-app
npm install
npm run tauri build
# Output: src-tauri/target/release/bundle/dmg/IPA-Keyboard.dmg
```

**macOS Signing:**
1. Obtain Apple Developer ID ($99/year)
2. Sign IME: `codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" IPAKeyboard.app`
3. Sign companion: Tauri handles this via `tauri.conf.json` signing config
4. Notarize: `xcrun notarytool submit IPAKeyboard.dmg --apple-id you@email.com --team-id XXXXX --password @keychain:AC_PASSWORD`
5. Staple: `xcrun stapler staple IPAKeyboard.dmg`

---

## 5. Progress Tracker

### Phase 1 — MVP (Companion App Standalone)

#### 1.1 Project Setup
- [x] Initialize Tauri + React project (`companion-app/`)
- [x] Initialize shared Rust crate (`ime-core/shared/`)
- [x] Configure TypeScript
- [ ] Set up Cargo workspace

#### 1.2 IPA Symbol Dataset
- [x] Create full `ipa-symbols.json` (~600 symbols)
- [x] Create `default-mappings.json` (Ctrl+key → symbol groups)
- [ ] Create `config-schema.json`

#### 1.3 Shared Mapping Engine (Rust)
- [ ] Implement `MappingEngine` struct
- [ ] Implement `cycle_next()` with timeout logic
- [ ] Implement `load_from_json()` config loader
- [ ] Unit tests for cycle engine

#### 1.4 Companion App — Text Editor
- [x] Basic text area with cursor control
- [x] Rich text toolbar (B, I, U, S, s, R)
- [x] Undo / Redo
- [x] Copy All / Copy Selected / Clear buttons
- [x] Ctrl+key cycling within the app (via `useSymbolCycle` hook)

#### 1.5 Companion App — Virtual Keyboard
- [x] `VirtualKeyboard` component (letter group grid layout)
- [x] `SymbolGroup` component (trigger letter + expandable symbols)
- [x] Click-to-insert at cursor position
- [x] Diacritics row (tones, length, stress, nasalization)
- [x] Suprasegmentals row (boundaries, linking)
- [x] Visual feedback on click (highlight/animation)

#### 1.6 Companion App — Document Management
- [x] Save current text as `.txt` (UTF-8)
- [x] Open existing `.txt` file
- [x] Recent documents list
- [x] Multi-document tabs or switcher
- [x] Auto-save session on close

#### 1.7 Companion App — Favorites & Frequency
- [x] Track symbol usage frequency (local JSON)
- [x] Favorites bar (pin/unpin symbols)
- [x] `useFrequencyTracker` hook
- [x] Sort by most-used option

#### 1.8 Companion App — Window Modes
- [x] Integrated panel mode (keyboard below editor)
- [x] Detachable floating window mode (Tauri `WebviewWindow`)
- [x] Toggle button between modes
- [x] Always-on-top option for floating window (pin/unpin toggle)

---

### Phase 2 — IME (macOS)

#### 2.1 macOS IME Core
- [ ] Create Swift package (`ime-core/macos/`)
- [ ] Implement `IPAInputController` (IMKInputController subclass)
- [ ] Implement `handleEvent` for Ctrl+key interception
- [ ] FFI bridge to shared Rust mapping engine
- [ ] `insertText` to commit IPA symbol to active app

#### 2.2 macOS IME Config
- [ ] Read shared config from `~/Library/Application Support/ipa-keyboard/`
- [ ] File watcher for config hot-reload
- [ ] Ctrl+Space toggle (English ↔ IPA mode)

#### 2.3 macOS IME Packaging
- [ ] Bundle as `.app` with IME extension
- [ ] `Info.plist` configuration
- [ ] Register in System Settings → Keyboard → Input Sources
- [ ] Installer integrates IME + companion app

#### 2.4 macOS Signing & Distribution

##### 2.4.1 Menu Bar Icon for IME
- [x] Create `ime-core/macos/scripts/generate-icon.sh` — generates template icons
- [x] Create `ime-core/macos/Resources/ipa.png` — 18×18 menu bar icon
- [x] Create `ime-core/macos/Resources/ipa@2x.png` — 36×36 retina icon
- Info.plist `tsInputMethodIconFileKey` already set to `ipa` ✓

##### 2.4.2 Code Signing + Hardened Runtime
- [x] Create `ime-core/macos/Resources/IPAKeyboard.entitlements`
- [x] Modify `ime-core/macos/build.sh` — add Step 4: code signing
  - Developer ID if `APPLE_SIGNING_IDENTITY` env var set
  - Hardened runtime (`--options runtime`)
  - Ad-hoc fallback (`-s -`) for local dev

##### 2.4.3 Notarization Script
- [x] Create `scripts/notarize-macos.sh`
  - Zip → submit via `xcrun notarytool` → wait → staple
  - Support API key auth and Apple ID auth via env vars

##### 2.4.4 Tauri Companion App Signing Config
- [x] Modify `companion-app/src-tauri/tauri.conf.json` — add macOS bundle config
- [x] Create `companion-app/src-tauri/Entitlements.plist`

##### 2.4.5 Unified Bundle Identifiers
- [x] Change IME bundle ID: `com.ipakeyboard.inputmethod` → `com.minhphan.ipa-keyboard.inputmethod`
- Companion app already `com.minhphan.ipa-keyboard` ✓

##### Files for 2.4
| File | Action | Subtask |
|---|---|---|
| `ime-core/macos/scripts/generate-icon.sh` | Create | 2.4.1 |
| `ime-core/macos/Resources/ipa.png` | Create | 2.4.1 |
| `ime-core/macos/Resources/ipa@2x.png` | Create | 2.4.1 |
| `ime-core/macos/Resources/IPAKeyboard.entitlements` | Create | 2.4.2 |
| `ime-core/macos/Resources/Info.plist` | Modify | 2.4.5 |
| `ime-core/macos/build.sh` | Modify | 2.4.2 |
| `scripts/notarize-macos.sh` | Create | 2.4.3 |
| `companion-app/src-tauri/tauri.conf.json` | Modify | 2.4.4 |
| `companion-app/src-tauri/Entitlements.plist` | Create | 2.4.4 |

##### Verification Checklist
- [ ] `bash ime-core/macos/build.sh` — builds and ad-hoc signs
- [ ] `codesign -dv --verbose=4 ime-core/macos/build/IPAKeyboard.app` — verify
- [ ] Menu bar icon visible after install to `~/Library/Input Methods/`
- [ ] `APPLE_SIGNING_IDENTITY="Developer ID Application: ..." bash build.sh` — proper signing
- [ ] `bash scripts/notarize-macos.sh ime-core/macos/build/IPAKeyboard.app` — notarize
- [ ] `cd companion-app && npm run tauri build` — Tauri builds with signing config

---

### Phase 3 — IME (Windows)

#### 3.1 Windows IME Core
- [x] Create Rust + COM project (`ime-core/windows/`)
- [x] Implement `ITfTextInputProcessor` (TIP entry point)
- [x] Implement `ITfKeyEventSink` (OnKeyDown/OnKeyUp)
- [x] Implement `ITfCompositionSink` (text insertion)
- [x] Implement `ITfThreadMgrEventSink` (lifecycle)
- [x] Wire up shared Rust mapping engine
- [x] DLL entry points (`DllGetClassObject`, `DllCanUnloadNow`, `DllRegisterServer`)
- [x] COM class factory
- [x] Self-registration via `register.rs` (COM + TSF profile + category)

#### 3.2 Windows IME Config
- [x] Read shared config from `%APPDATA%/ipa-keyboard/`
- [ ] File watcher for config hot-reload
- [x] Ctrl+Space toggle (English ↔ IPA mode)

#### 3.3 Windows IME Packaging
- [x] Build as DLL (cdylib crate type)
- [x] COM registration script (`register.ps1`)
- [x] Self-registration via `regsvr32` (DllRegisterServer/DllUnregisterServer)
- [x] Build script (`scripts/build-windows.ps1`)
- [ ] MSI installer bundles DLL + companion app

#### 3.4 Windows Signing & Distribution
- [ ] Obtain EV Code Signing Certificate
- [x] Sign DLL with `signtool` (in build-windows.ps1)
- [x] Sign MSI with `signtool` (in build-windows.ps1)
- [ ] Test Windows Defender / SmartScreen acceptance

---

### Phase 4 — Polish & Extras

#### 4.1 Composition Buffer (v2)
- [x] Multi-key sequence support (t+h → θ)
- [x] Composition preview (marked text)
- [x] Configurable sequences in JSON

#### 4.2 Symbol Search
- [x] Search by IPA name ("voiced bilabial fricative" → β)
- [x] Search by Unicode codepoint
- [x] Fuzzy matching

#### 4.3 Candidate Selection
- [x] Dropdown candidate list (like Chinese IME)
- [x] Arrow keys to select, Enter to commit

#### 4.4 Quality of Life
- [ ] Auto-update mechanism
- [x] Onboarding / first-run tutorial
- [x] Keyboard shortcut cheat sheet overlay
- [x] Theme support (light/dark)

---

### Phase 5 — Mac App Store Submission

> **Distribution strategy**: Companion App via Mac App Store (sandboxed). IME via Developer ID + notarization from website (Apple prohibits InputMethodKit in sandbox — instant rejection).

#### 5.1 App Sandbox (BLOCKER)
- [x] Add `com.apple.security.app-sandbox = true` to `companion-app/src-tauri/Entitlements.plist`
- [x] Keep existing entitlements (JIT, disable-library-validation, user-selected files) — all sandbox-compatible
- [ ] Verify file open/save dialogs still work under sandbox

#### 5.2 Privacy Manifest (BLOCKER)
- [x] Create `companion-app/src-tauri/PrivacyInfo.xcprivacy`
  - `NSPrivacyTracking = false`
  - Accessed API types: UserDefaults (Tauri window state), FileTimestamp (fs plugin), DiskSpace (file saves)
- [x] Add `"PrivacyInfo.xcprivacy"` to `bundle.resources` in `tauri.conf.json`
- [ ] Verify file appears in built `.app` bundle at `Contents/Resources/PrivacyInfo.xcprivacy`

#### 5.3 Native macOS Menu Bar (HIGH — likely rejection without it)
- [x] Add standard menus to `companion-app/src-tauri/src/lib.rs` using Tauri v2 Menu API
  - App menu (About, Hide, Quit)
  - File menu (Close)
  - Edit menu (Undo, Redo, Cut, Copy, Paste, Select All)
  - View menu (Full Screen)
  - Window menu (Minimize)

#### 5.4 App Store Upload Script
- [x] Create `scripts/upload-appstore.sh`
  - Validate signing identity is "3rd Party Mac Developer Application"
  - Create `.pkg` with `productbuild --sign "3rd Party Mac Developer Installer"`
  - Validate with `xcrun altool --validate-app`
  - Upload with `xcrun altool --upload-app`

#### 5.5 IME Entitlements Documentation
- [x] Add XML comments to `ime-core/macos/Resources/IPAKeyboard.entitlements` explaining:
  - IME cannot be sandboxed (InputMethodKit requirement)
  - Distributed via Developer ID + notarization
  - Hardened runtime enforced at signing time

#### 5.6 Distribution Documentation
- [x] Create `docs/DISTRIBUTION.md` documenting:
  - Companion App: Mac App Store (sandboxed, "3rd Party Mac Developer" cert)
  - IME: Developer ID + notarization (not sandboxed, "Developer ID Application" cert)
  - Required Apple Developer certificates
  - Build and upload commands for each path

#### 5.7 Mac App Store Onboarding Guide
- [x] Create `docs/MAC-APP-STORE-GUIDE.md` — step-by-step guide covering:
  1. **Prerequisites**: Apple Developer Program enrollment ($99/year), Xcode installed
  2. **Certificates**: Create "3rd Party Mac Developer Application" + "3rd Party Mac Developer Installer" certs via Apple Developer portal
  3. **App Store Connect**: Create app record with bundle ID `com.minhphan.ipa-keyboard`, set pricing (Free), add description/screenshots/keywords
  4. **Provisioning Profile**: Create Mac App Store provisioning profile, download and install
  5. **Build**: `cd companion-app && npm run tauri build` with signing identity set
  6. **Package**: `productbuild --component ... --sign ... .pkg`
  7. **Validate**: `xcrun altool --validate-app --file .pkg`
  8. **Upload**: `xcrun altool --upload-app --file .pkg` (or use Transporter.app)
  9. **Submit for Review**: In App Store Connect, select build, add review notes explaining JIT + disable-library-validation justification (Tauri/WKWebView), submit
  10. **Review Notes Template**: Pre-written justification for entitlements (JIT for WKWebView, library validation for Tauri plugins)
  11. **Post-Approval**: Monitor for crashes in App Store Connect, respond to user reviews
  12. **Updates**: How to push version updates (bump version, rebuild, re-upload)

##### Files for Phase 5
| File | Action | Subtask |
|---|---|---|
| `companion-app/src-tauri/Entitlements.plist` | Modify | 5.1 |
| `companion-app/src-tauri/PrivacyInfo.xcprivacy` | Create | 5.2 |
| `companion-app/src-tauri/tauri.conf.json` | Modify | 5.2 |
| `companion-app/src-tauri/src/lib.rs` | Modify | 5.3 |
| `scripts/upload-appstore.sh` | Create | 5.4 |
| `ime-core/macos/Resources/IPAKeyboard.entitlements` | Modify | 5.5 |
| `docs/DISTRIBUTION.md` | Create | 5.6 |
| `docs/MAC-APP-STORE-GUIDE.md` | Create | 5.7 |

---

## 6. Decision Log

| # | Decision | Alternatives Considered | Rationale |
|---|----------|------------------------|-----------|
| 1 | Hybrid architecture (IME + Tauri companion) | Tauri-only app, Full native app | IME gives system-wide input; Tauri gives easy cross-platform UI |
| 2 | Rust for shared mapping engine | Pure Swift + Pure C++ per platform | One codebase for core logic, FFI to both platforms |
| 3 | Shared JSON config for IPC | Named pipes, Unix sockets | Simplest reliable cross-platform IPC; file watching is sufficient |
| 4 | Ctrl+key for cycling (not Alt+key) | Alt+key, custom modifier | Ctrl is standard IME modifier; avoids conflicts with OS Alt shortcuts |
| 5 | Documents saved as .txt | .rtf, custom JSON format | User preference; rich formatting is display-only |
| 6 | TSF for Windows IME | IMM32 (legacy), global hooks | TSF is modern, approved API; passes Defender |
| 7 | InputMethodKit for macOS IME | Carbon IME (deprecated), accessibility hooks | IMK is Apple's official framework; passes Gatekeeper |
| 8 | Phase 1 = companion app only | Build IME first | Companion app is usable standalone; IME is high-complexity |
| 9 | Cycle timeout (800ms default) | No timeout, configurable only | Prevents stuck cycles; 800ms is natural typing pause |
| 10 | Two-tier distribution (App Store + Developer ID) | Single installer, App Store only | Apple prohibits InputMethodKit in sandbox; IME must use Developer ID + notarization |

---

## 7. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| TSF COM complexity | High | Use existing Rust COM crates (windows-rs); start with minimal TIP |
| IMK deprecation risk | Medium | Apple still supports IMK; monitor WWDC announcements |
| Font coverage gaps | Low | Bundle fallback font or recommend specific fonts per OS |
| Signing cost | Medium | EV cert ~$300-500/yr, Apple Dev ~$99/yr; required for trust |
| Cross-platform config sync | Low | Simple JSON file; both sides validate schema |

---

## 8. Assumptions

1. IPA symbol dataset is static (~600 symbols), no dynamic updates needed
2. Cycle timeout of 800ms is acceptable default (configurable)
3. Users will install IME via installer (not manual registration)
4. Companion app and IME are installed together via single installer
5. No need for cloud sync or multi-device support
6. Rich text formatting in editor is cosmetic only (not saved)
7. Two-tier macOS distribution: Companion App via App Store, IME via Developer ID + notarization
