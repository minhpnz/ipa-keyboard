# IPA Keyboard — Developer Guide

## Prerequisites

- **macOS 12+** (Monterey or later)
- **Rust** — `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **Rust targets** — `rustup target add aarch64-apple-darwin x86_64-apple-darwin`
- **Node.js 18+** — for the companion app frontend
- **Tauri CLI** — `cargo install tauri-cli`

## Project Structure

```
ipa-keyboard/
├── companion-app/                # Tauri + React desktop app
│   ├── src/                      # React frontend (TypeScript)
│   │   ├── components/           # VirtualKeyboard, Onboarding, CheatSheet, etc.
│   │   └── data/                 # ipa-symbols.json, default-mappings.ts
│   └── src-tauri/                # Tauri backend (Rust)
│       ├── src/lib.rs            # App entry: daemon lifecycle, tray icon, menus
│       ├── Entitlements.plist    # Hardened Runtime entitlements
│       └── icons/                # App icon, tray icon
├── ime-core/
│   ├── shared/                   # ipa-mapping-engine library (Rust)
│   │   └── src/engine.rs         # Cycling logic, case handling, reset
│   └── macos/                    # macOS daemon (CGEvent tap)
│       ├── src/
│       │   ├── main.rs           # Daemon entry, config loading, permission check
│       │   ├── event_tap.rs      # CGEvent tap: intercepts Ctrl+key system-wide
│       │   └── injector.rs       # Injects IPA text via CGEvent (Private source)
│       ├── tests/integration_test.rs  # 21 tests covering all mappings
│       └── Resources/            # Daemon entitlements, Info.plist
├── shared-config/
│   └── default-mappings.json     # 22 keys → 38 IPA symbols
├── scripts/                      # Build/deploy scripts
└── docs/
```

## Architecture

```
Companion App (Tauri)              Daemon (CGEvent tap)
┌───────────────────────┐         ┌─────────────────────────┐
│ React UI              │ spawns  │ CGEventTapCreate         │
│ - Visual keyboard     │────────→│ - Intercepts Ctrl+key    │
│ - IPA editor          │         │ - Looks up mapping       │
│ - Tray icon (IPA)     │         │ - Injects IPA via CGEvent│
│ - Onboarding          │         │ - Private event source   │
└───────────────────────┘         └─────────────────────────┘
                                           ↓
                                  All apps (Chrome, VSCode, Word...)
```

**Daemon lifecycle**: The companion app manages the daemon via PID file at
`~/Library/Application Support/ipa-keyboard/daemon.pid`. On launch it spawns
the daemon; on quit it sends SIGTERM. No `pgrep`/`pkill` — clean process management.

**Event flow**: Ctrl+key → CGEvent tap callback → keycode_to_letter() → engine.cycle_next() → injector::type_text() with Ctrl flag cleared → target app receives plain IPA text.

**Key design decisions**:
- `CGEventSourceStateID::Private` prevents the tap from seeing its own injected events
- `CGEventFlags::CGEventFlagNonCoalesced` clears Ctrl on injected events so target apps see plain text
- `INJECTED_EVENT_TAG` (0x495041 = "IPA") as defense-in-depth against re-entry
- Global tap pointer stored for re-enabling after macOS timeout disables

## Current Mapping (22 keys → 38 symbols)

| Key | Symbols |
|-----|---------|
| A | æ → ɑ → ɑː → ʌ |
| E | e → ə → ɜː |
| I | ɪ → iː |
| O | ɒ → ɔ → ɔː |
| U | ʊ → uː |
| T | t → θ → ð |
| S | s → ʃ → ʒ |
| D | d → dʒ |
| C | k → tʃ |
| N | n → ŋ |
| R L H M F V B P G Z W J | single symbol each |

## Building

### Daemon only

```bash
cargo build -p ipa-keyboard-daemon --release
# Binary: target/release/ipa-keyboard-daemon
```

### Universal binary (Intel + Apple Silicon)

```bash
cargo build -p ipa-keyboard-daemon --release --target aarch64-apple-darwin
cargo build -p ipa-keyboard-daemon --release --target x86_64-apple-darwin
lipo -create \
  target/aarch64-apple-darwin/release/ipa-keyboard-daemon \
  target/x86_64-apple-darwin/release/ipa-keyboard-daemon \
  -output target/release/ipa-keyboard-daemon-universal
```

### Full app (companion + daemon + DMG)

```bash
# 1. Build universal daemon
# (commands above)

# 2. Build universal Tauri app
cd companion-app
npm install
npm run tauri build -- --target universal-apple-darwin

# 3. Bundle daemon into .app
APP="src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app"
cp ../target/release/ipa-keyboard-daemon-universal "$APP/Contents/MacOS/ipa-keyboard-daemon"
chmod +x "$APP/Contents/MacOS/ipa-keyboard-daemon"

# 4. Create DMG
hdiutil create -volname "IPA Keyboard" -srcfolder "$APP" -ov -format UDZO ~/Desktop/IPA-Keyboard.dmg
```

### Development mode

```bash
# Terminal 1: Run daemon (needs Accessibility permission)
cargo run -p ipa-keyboard-daemon --release

# Terminal 2: Run companion app
cd companion-app && npm run tauri dev
```

## Testing

```bash
cargo test -p ipa-keyboard-daemon    # 21 integration tests
cargo test -p ipa-mapping-engine     # Engine unit tests
cargo test                           # All workspace tests
```

The 21 integration tests cover: all 22 keys produce symbols, correct first symbol per key, full cycling for all multi-symbol keys (a/e/i/o/u/t/s/d/c/n), single-symbol key wrapping, key switching resets cycle, unmapped keys return None, character counts for backspace, UTF-16 encoding roundtrip, backspace count consistency, keycode coverage, case insensitivity, and all 38 symbols reachable.

## Permissions

The daemon requires **Accessibility permission** for CGEvent tap.

- First run triggers the macOS permission dialog via `AXIsProcessTrustedWithOptions`
- Daemon polls every 2s until granted, then installs the tap
- Permission is per-binary (hash-based) — recompiling requires re-granting
- If running from VS Code terminal, VS Code itself also needs Accessibility permission

## Signing & Notarization

Distribution is **Developer ID + notarization** (not Mac App Store).

### Required certificates
- **Developer ID Application** — signs all binaries (.app and daemon)
- **Apple Developer account** with App Store Connect API key for `notarytool`

### Signing

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Sign daemon with Hardened Runtime + entitlements
codesign --force --options runtime \
  --entitlements ime-core/macos/Resources/IPAKeyboard.entitlements \
  --sign "$IDENTITY" \
  "IPA Keyboard.app/Contents/MacOS/ipa-keyboard-daemon"

# Sign the main app
codesign --force --options runtime \
  --entitlements companion-app/src-tauri/Entitlements.plist \
  --sign "$IDENTITY" \
  "IPA Keyboard.app"
```

### Notarization

```bash
# Create ZIP for upload
ditto -c -k --keepParent "IPA Keyboard.app" IPA-Keyboard.zip

# Submit
xcrun notarytool submit IPA-Keyboard.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple "IPA Keyboard.app"

# Re-create DMG with stapled app
hdiutil create -volname "IPA Keyboard" -srcfolder "IPA Keyboard.app" -ov -format UDZO IPA-Keyboard.dmg
```

### Entitlements

**Companion app** (`Entitlements.plist`):
- `com.apple.security.cs.allow-jit` — WKWebView JavaScript
- `com.apple.security.cs.disable-library-validation` — Tauri plugin dylibs

**Daemon** (`IPAKeyboard.entitlements`):
- `com.apple.security.cs.allow-unsigned-executable-memory` — CGEvent callback
- `com.apple.security.cs.disable-library-validation` — Rust runtime

No App Sandbox — CGEvent taps are incompatible with sandbox.

## Modifying Mappings

Edit `shared-config/default-mappings.json`:

```json
{
  "cycle_timeout_ms": 800,
  "mappings": {
    "a": ["æ", "ɑ", "ɑː", "ʌ"],
    "t": ["t", "θ", "ð"],
    ...
  }
}
```

After editing:
1. Update `companion-app/src/data/ipa-symbols.json` → `letterGroups` to match
2. Update `companion-app/src/data/default-mappings.ts` to match
3. Run `cargo test -p ipa-keyboard-daemon` and update tests as needed

Users can override at runtime: `~/Library/Application Support/ipa-keyboard/config.json`
