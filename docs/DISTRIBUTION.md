# IPA Keyboard — Distribution & Notarization

## Distribution Model

**Developer ID + Notarization** (direct download from website).

Not Mac App Store — CGEvent taps require Accessibility permission which is incompatible with App Sandbox. This is the same distribution model used by Karabiner-Elements, BetterTouchTool, Rectangle, and other keyboard utilities.

## What Users Experience

1. Download DMG from website
2. Open DMG, drag to Applications
3. First launch: macOS Gatekeeper verifies the notarization ticket — no "unidentified developer" warning
4. App prompts for Accessibility permission (one-time)
5. Everything works

## Prerequisites

- Apple Developer Program membership ($99/year)
- **Developer ID Application** certificate (for signing)
- App Store Connect API key (for `notarytool`) or app-specific password

## Build (Universal Binary)

```bash
# 1. Build daemon for both architectures
cargo build -p ipa-keyboard-daemon --release --target aarch64-apple-darwin
cargo build -p ipa-keyboard-daemon --release --target x86_64-apple-darwin

# 2. Create universal daemon binary
lipo -create \
  target/aarch64-apple-darwin/release/ipa-keyboard-daemon \
  target/x86_64-apple-darwin/release/ipa-keyboard-daemon \
  -output target/release/ipa-keyboard-daemon-universal

# 3. Build universal Tauri app
cd companion-app
npm run tauri build -- --target universal-apple-darwin

# 4. Bundle daemon into .app
APP="src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app"
cp ../target/release/ipa-keyboard-daemon-universal "$APP/Contents/MacOS/ipa-keyboard-daemon"
chmod +x "$APP/Contents/MacOS/ipa-keyboard-daemon"
```

## Sign

Sign from the inside out — daemon first, then the app bundle.

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Sign daemon binary (inside the .app)
codesign --force --options runtime \
  --entitlements ../ime-core/macos/Resources/IPAKeyboard.entitlements \
  --sign "$IDENTITY" \
  "$APP/Contents/MacOS/ipa-keyboard-daemon"

# Sign Tauri frameworks/dylibs
find "$APP/Contents/Frameworks" -name "*.dylib" -exec \
  codesign --force --options runtime --sign "$IDENTITY" {} \;

# Sign the main app bundle
codesign --force --options runtime \
  --entitlements src-tauri/Entitlements.plist \
  --sign "$IDENTITY" \
  "$APP"

# Verify
codesign --verify --deep --strict "$APP"
spctl --assess --type execute "$APP"
```

## Notarize

```bash
# Create ZIP for upload
ditto -c -k --keepParent "$APP" IPA-Keyboard.zip

# Submit to Apple (using API key method)
xcrun notarytool submit IPA-Keyboard.zip \
  --key /path/to/AuthKey.p8 \
  --key-id "KEY_ID" \
  --issuer "ISSUER_UUID" \
  --wait

# Or using app-specific password
xcrun notarytool submit IPA-Keyboard.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait

# Staple the notarization ticket to the app
xcrun stapler staple "$APP"

# Verify stapling
xcrun stapler validate "$APP"
```

## Create DMG

```bash
# Create final DMG with notarized + stapled app
hdiutil create \
  -volname "IPA Keyboard" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  ~/Desktop/IPA-Keyboard-0.1.0-universal.dmg

# Notarize the DMG too
xcrun notarytool submit ~/Desktop/IPA-Keyboard-0.1.0-universal.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait

xcrun stapler staple ~/Desktop/IPA-Keyboard-0.1.0-universal.dmg
```

## Entitlements

### Companion App (`Entitlements.plist`)

| Entitlement | Reason |
|---|---|
| `com.apple.security.cs.allow-jit` | WKWebView requires JIT for JavaScript |
| `com.apple.security.cs.disable-library-validation` | Tauri loads plugin dylibs at runtime |

### Daemon (`IPAKeyboard.entitlements`)

| Entitlement | Reason |
|---|---|
| `com.apple.security.cs.allow-unsigned-executable-memory` | CGEvent tap callback function pointers |
| `com.apple.security.cs.disable-library-validation` | Rust runtime |

**No App Sandbox** on either binary. CGEvent taps cannot operate inside a sandbox.

## Notarization Checklist

- [ ] All binaries signed with Developer ID Application certificate
- [ ] Hardened Runtime enabled on all binaries (`--options runtime`)
- [ ] Entitlements applied to both app and daemon
- [ ] No unsigned frameworks or dylibs in the bundle
- [ ] `codesign --verify --deep --strict` passes
- [ ] `spctl --assess --type execute` passes
- [ ] `notarytool submit` succeeds
- [ ] `stapler staple` applied to both .app and .dmg
- [ ] DMG downloads and opens without Gatekeeper warning on a clean Mac

## Version Bumping

Update these files before each release:

| File | Field |
|------|-------|
| `companion-app/src-tauri/tauri.conf.json` | `version` |
| `companion-app/src-tauri/Cargo.toml` | `version` |
| `companion-app/package.json` | `version` |
| `ime-core/macos/Resources/Info.plist` | `CFBundleShortVersionString`, `CFBundleVersion` |
| `ime-core/shared/Cargo.toml` | `version` |
| `ime-core/macos/Cargo.toml` | `version` |

## Common Notarization Errors

| Error | Fix |
|---|---|
| "The signature does not include a secure timestamp" | Add `--timestamp` to codesign (included by default with `--options runtime`) |
| "The executable does not have the hardened runtime enabled" | Add `--options runtime` to codesign |
| "The binary uses an SDK older than 10.9" | Ensure `LSMinimumSystemVersion` is set to 12.0+ |
| "The signature of the binary is invalid" | Sign inside-out: daemon first, then app bundle |
| "A sealed resource is missing or invalid" | Run `codesign --deep` or sign each component individually |
