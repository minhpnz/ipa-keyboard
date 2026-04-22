# Mac App Store Submission Guide — IPA Keyboard Companion App

Step-by-step guide to publish the IPA Keyboard companion app on the Mac App Store.

---

## 1. Prerequisites

- [ ] **Apple Developer Program** membership ($99/year) — [enroll here](https://developer.apple.com/programs/)
- [ ] **Xcode** installed (for Transporter and certificate management)
- [ ] **Node.js** and **Rust** toolchains installed
- [ ] Project builds successfully: `cd companion-app && npm run tauri build`

---

## 2. Create Certificates

Go to [Apple Developer > Certificates](https://developer.apple.com/account/resources/certificates/list):

1. Click `+` to create a new certificate
2. Create **3rd Party Mac Developer Application** certificate
   - Generate a Certificate Signing Request (CSR) from Keychain Access:
     - Open Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority
     - Enter your email, select "Saved to disk"
   - Upload the CSR to the Developer portal
   - Download and double-click to install in Keychain
3. Create **3rd Party Mac Developer Installer** certificate (same process)

Verify certificates are installed:
```bash
security find-identity -v -p basic | grep "3rd Party"
```

You should see two entries:
```
"3rd Party Mac Developer Application: Your Name (TEAMID)"
"3rd Party Mac Developer Installer: Your Name (TEAMID)"
```

---

## 3. Create Provisioning Profile

Go to [Apple Developer > Profiles](https://developer.apple.com/account/resources/profiles/list):

1. Click `+` to create a new profile
2. Select **Mac App Store** distribution type
3. Select your App ID: `com.minhphan.ipa-keyboard`
   - If it doesn't exist, create it under [Identifiers](https://developer.apple.com/account/resources/identifiers/list)
4. Select your "3rd Party Mac Developer Application" certificate
5. Download the `.provisionprofile` file
6. Double-click to install, or copy to `~/Library/MobileDevice/Provisioning Profiles/`

---

## 4. Set Up App Store Connect

Go to [App Store Connect](https://appstoreconnect.apple.com):

1. Click `+` > **New App**
2. Fill in:
   - **Platform**: macOS
   - **Name**: IPA Keyboard
   - **Primary Language**: English
   - **Bundle ID**: `com.minhphan.ipa-keyboard`
   - **SKU**: `ipa-keyboard` (any unique string)
3. Under **Pricing and Availability**:
   - Set price to **Free**
4. Under **App Information**:
   - **Category**: Utilities
   - **Subcategory**: (optional)
5. Under **Prepare for Submission**:
   - Add **screenshots** (at least 1280x800 or 2560x1600 for Retina)
   - Write **description**: "Type IPA (International Phonetic Alphabet) symbols in a visual editor. Features a virtual keyboard, symbol search, document management, and keyboard shortcut cycling."
   - Add **keywords**: `IPA, phonetics, linguistics, phonetic alphabet, symbols, transcription`
   - Set **age rating**: 4+
   - Add **privacy policy URL** (required even for offline apps)

---

## 5. Build the App

```bash
cd companion-app

# Set the Mac App Store signing identity
export APPLE_SIGNING_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAMID)"

# Build
npm run tauri build
```

The built app will be at:
```
companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app
```

### Verify the build

```bash
APP="companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"

# Check signing
codesign --verify --deep --strict "$APP"

# Check entitlements include sandbox
codesign -d --entitlements :- "$APP" 2>&1 | grep app-sandbox

# Check PrivacyInfo.xcprivacy is bundled
ls "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
```

---

## 6. Package as .pkg

App Store submissions require a `.pkg` installer, not a bare `.app`:

```bash
export MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)"

productbuild \
    --component "companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app" /Applications \
    --sign "$MAS_INSTALLER_IDENTITY" \
    "IPA-Keyboard.pkg"
```

Or use the provided script:
```bash
export MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)"
export MAS_API_KEY_ID="XXXXXXXXXX"
export MAS_API_KEY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export MAS_API_KEY_PATH="/path/to/AuthKey.p8"

bash scripts/upload-appstore.sh "companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"
```

---

## 7. Validate

Before uploading, validate the package:

```bash
xcrun altool --validate-app \
    --file "IPA-Keyboard.pkg" \
    --type macos \
    --apiKey "$MAS_API_KEY_ID" \
    --apiIssuer "$MAS_API_KEY_ISSUER"
```

Common validation errors:
- **Missing provisioning profile**: Install the profile from step 3
- **Bundle ID mismatch**: Ensure `tauri.conf.json` identifier matches App Store Connect
- **Missing icons**: Ensure all icon sizes are present in `src-tauri/icons/`
- **Missing PrivacyInfo.xcprivacy**: Check it's listed in `tauri.conf.json` bundle resources

---

## 8. Upload

### Option A: Command line (recommended for CI)
```bash
xcrun altool --upload-app \
    --file "IPA-Keyboard.pkg" \
    --type macos \
    --apiKey "$MAS_API_KEY_ID" \
    --apiIssuer "$MAS_API_KEY_ISSUER"
```

### Option B: Transporter app
1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from the App Store
2. Open Transporter, sign in with your Apple ID
3. Drag `IPA-Keyboard.pkg` into the window
4. Click **Deliver**

---

## 9. Submit for Review

In [App Store Connect](https://appstoreconnect.apple.com):

1. Go to your app > **macOS** > **Prepare for Submission**
2. Under **Build**, click `+` and select the uploaded build (may take a few minutes to appear)
3. Fill in **Review Notes** with the following entitlement justifications:

### Review Notes Template

```
This app is built with the Tauri framework (https://tauri.app), which uses
macOS native WKWebView for its user interface.

ENTITLEMENT JUSTIFICATIONS:

1. com.apple.security.cs.allow-jit
   Tauri's WKWebView requires JIT compilation for JavaScript execution.
   This is a standard requirement for all Tauri-based macOS applications.
   The app's Content Security Policy restricts scripts to 'self' only,
   preventing any remote code execution.

2. com.apple.security.cs.disable-library-validation
   Tauri loads its core plugins (filesystem access, file dialogs, URL opener)
   as dynamic libraries at runtime. These plugins are bundled within the app
   package but are not individually code-signed by Apple. This entitlement
   is required for Tauri's plugin architecture to function.

3. com.apple.security.files.user-selected.read-write
   The app is a document editor for IPA phonetic transcriptions. Users
   open and save .txt files through standard NSOpenPanel/NSSavePanel dialogs.

The app is fully offline — no network connections, no telemetry, no user
accounts, no cloud services. All data stays on the user's machine.
```

4. Click **Submit for Review**

---

## 10. After Approval

### Monitor
- Check App Store Connect for crash reports
- Respond to user reviews

### Push Updates
1. Bump version in all files (see `docs/DISTRIBUTION.md` for the list)
2. Rebuild: `npm run tauri build`
3. Re-package and re-upload using the same process
4. In App Store Connect, create a new version and submit

### Version Numbering
- `CFBundleShortVersionString` (e.g. "1.0.0") — shown to users
- `CFBundleVersion` (e.g. "1", "2", "3") — must increment with every upload, even for the same marketing version

---

## Troubleshooting

### "No suitable signing identity found"
Install the certificates from step 2. Run:
```bash
security find-identity -v -p basic | grep "3rd Party"
```

### "App sandbox not enabled"
Ensure `Entitlements.plist` contains `com.apple.security.app-sandbox = true`. Check:
```bash
codesign -d --entitlements :- "IPA Keyboard.app" 2>&1 | grep sandbox
```

### "Missing privacy manifest"
Ensure `PrivacyInfo.xcprivacy` is listed in `tauri.conf.json` under `bundle.resources` and appears in the built app at `Contents/Resources/PrivacyInfo.xcprivacy`.

### Build rejected for non-native UI
The app uses standard macOS menus (File, Edit, View, Window) via Tauri's native menu API. If reviewers flag UI issues, check that the menu bar is visible and functional.

### "This app cannot be sandboxed"
This error applies to the **IME** (InputMethodKit), not the companion app. The IME cannot go to the App Store — see `docs/DISTRIBUTION.md` for the two-tier distribution strategy.
