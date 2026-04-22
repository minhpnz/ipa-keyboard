# Phase 7 — App Store criteria + CI preflight

**Ships:** Production-ready `Info.plist` + `PrivacyInfo.xcprivacy` in both targets, empty entitlements confirmed, extension scrubbed of forbidden APIs, and `ios/Scripts/preflight.sh` expanded to all 8 guards from spec §9.8 plus a committed size baseline.

**Spec sections:** §9.2 entitlements, §9.3 extension Info.plist, §9.4 privacy manifest, §9.6 review notes, §9.7 submission checklist, §9.8 CI preflight.

**Pre-req:** Phases 1–6 complete. App is functionally finished; this phase hardens it for review.

---

## Task 7.1 — Audit entitlements (both targets)

**Files:**
- Modify (verify contents): `ios/IPAKeyboardApp/IPAKeyboardApp.entitlements`
- Modify (verify contents): `ios/IPAKeyboardExtension/IPAKeyboardExtension.entitlements`

- [ ] **Step 1: Verify each is an empty dict**

Both files should contain exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

Run: `cat ios/IPAKeyboardApp/IPAKeyboardApp.entitlements ios/IPAKeyboardExtension/IPAKeyboardExtension.entitlements`

- [ ] **Step 2: Verify Xcode signing config**

Project settings → each target → Signing & Capabilities:
- Capability list is **empty** (no App Groups, no Network Extensions, no nothing)
- "Code Signing Entitlements" points at the correct `.entitlements` file
- "Provisioning Profile" = Automatic (personal team) for now; production profile is a Phase 8 concern

- [ ] **Step 3: Spot-check via grep**

Run:
```bash
grep -R 'com.apple.security' ios/IPAKeyboardApp*.entitlements ios/IPAKeyboardExtension*.entitlements 2>&1 | grep -v 'No such file'
```
Expected: empty output (no security entries).

Run:
```bash
grep -R 'group\.\|keychain-access-groups\|network\.client\|network\.server' \
     ios/IPAKeyboardApp/ ios/IPAKeyboardExtension/ 2>&1
```
Expected: empty output.

- [ ] **Step 4: Commit (if any edits were needed)**

```bash
git add ios/IPAKeyboardApp/IPAKeyboardApp.entitlements \
        ios/IPAKeyboardExtension/IPAKeyboardExtension.entitlements
git commit -m "ios: confirm both targets have empty entitlements

No App Group, no Full Access, no network, no keychain-access-groups.
The privacy story is literally nothing declared."
```

If no edits were needed, skip the commit.

---

## Task 7.2 — Finalize extension `Info.plist`

**Files:**
- Modify: `ios/IPAKeyboardExtension/Info.plist`

- [ ] **Step 1: Verify the exact keys from spec §9.3**

Open `ios/IPAKeyboardExtension/Info.plist`. It must contain (among Xcode's defaults):

```xml
<key>MinimumOSVersion</key>
<string>16.0</string>

<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <true/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>en-US</string>
        <key>RequestsOpenAccess</key>
        <false/>
    </dict>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
</dict>
```

Additionally, set these standard keys (Xcode may have them already — verify):

```xml
<key>CFBundleDisplayName</key>
<string>IPA Keyboard</string>
<key>CFBundleShortVersionString</key>
<string>1.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

- [ ] **Step 2: Verify no stray keys creep in**

Run:
```bash
plutil -p ios/IPAKeyboardExtension/Info.plist | grep -E 'UIBackgroundModes|NSAppTransportSecurity|NSLocationWhenInUseUsageDescription|NSCameraUsageDescription|NSMicrophoneUsageDescription|NSContactsUsageDescription|NSCalendarsUsageDescription|NSPhotoLibraryUsageDescription|NSFaceIDUsageDescription'
```
Expected: empty. A keyboard extension should declare **no** usage descriptions.

- [ ] **Step 3: Commit**

```bash
git add ios/IPAKeyboardExtension/Info.plist
git commit -m "ios: finalize extension Info.plist per spec §9.3

CFBundleDisplayName 'IPA Keyboard'. CFBundleShortVersionString 1.0, Build 1.
No privacy usage descriptions anywhere — the extension has no reason to ask."
```

---

## Task 7.3 — `PrivacyInfo.xcprivacy` in both targets

**Files:**
- Create: `ios/IPAKeyboardApp/PrivacyInfo.xcprivacy`
- Create: `ios/IPAKeyboardExtension/PrivacyInfo.xcprivacy`

Both files are **identical** per spec §9.4.

- [ ] **Step 1: Write the file**

Content (same for both paths):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Write both files.

- [ ] **Step 2: Add each file to its target in Xcode**

Xcode → drag `ios/IPAKeyboardApp/PrivacyInfo.xcprivacy` into `IPAKeyboardApp` target's file list (target membership checkbox: `IPAKeyboardApp` only). Same for the extension file with `IPAKeyboardExtension`.

Double-check: project settings → target → Build Phases → Copy Bundle Resources → `PrivacyInfo.xcprivacy` appears.

- [ ] **Step 3: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator build | tail -5`
Expected: success, and look for `PrivacyInfo.xcprivacy` in the build log's "Copy Bundle Resources" phase.

- [ ] **Step 4: Validate with Apple's privacy tool**

```bash
# Find the built app bundle:
xcrun simctl get_app_container booted com.minhphan.ipa-keyboard-ios app 2>/dev/null | xargs -I {} \
    find {} -name 'PrivacyInfo.xcprivacy'
```

If both files are present (one inside the app bundle, one inside `PlugIns/IPAKeyboardExtension.appex/`), you're clean.

Apple's `PrivacyReport` tool (available in Xcode 15.3+): Xcode → Product → Archive → once archived → Distribute App → Direct Distribution → Show Privacy Report. Verify it lists:
- Tracking: No
- Data Types Collected: None
- Required-reason APIs: UserDefaults (CA92.1)

This is optional for local dev but required before Phase 8.

- [ ] **Step 5: Commit**

```bash
git add ios/IPAKeyboardApp/PrivacyInfo.xcprivacy \
        ios/IPAKeyboardExtension/PrivacyInfo.xcprivacy \
        ios/IPAKeyboard.xcodeproj/
git commit -m "ios: PrivacyInfo.xcprivacy in both targets

Declares no tracking, no data types collected, UserDefaults CA92.1.
Per spec §9.4 — identical file in both targets."
```

---

## Task 7.4 — Extension forbidden-API scrub

**Files:**
- (Audit only, no code creation)

- [ ] **Step 1: Grep for each forbidden API**

Run each from the repo root:

```bash
# Should all be empty.  If any match, remove or move the usage to the container app.
echo "=== UIPasteboard in extension ==="
grep -Rn 'UIPasteboard' ios/IPAKeyboardExtension/ 2>&1 || true

echo "=== CLLocation ==="
grep -RnE 'CLLocation|CLLocationManager' ios/IPAKeyboardExtension/ 2>&1 || true

echo "=== AVAudio ==="
grep -RnE 'AVAudioSession|AVAudioEngine|AVAudioRecorder' ios/IPAKeyboardExtension/ 2>&1 || true

echo "=== Tracking APIs ==="
grep -RnE 'ASIdentifierManager|advertisingIdentifier|identifierForVendor' ios/IPAKeyboardExtension/ 2>&1 || true

echo "=== Contacts / Photos ==="
grep -RnE 'CNContact|PHPhotoLibrary' ios/IPAKeyboardExtension/ 2>&1 || true

echo "=== Network APIs ==="
grep -RnE 'URLSession|NWConnection|\.network' ios/IPAKeyboardExtension/ 2>&1 || true
```

Expected: every grep returns nothing.

If anything shows up: fix it before proceeding. UIPasteboard specifically must only exist in the **container app** (`ReferenceView`), never the extension.

- [ ] **Step 2: Commit (no code change; just document the clean state)**

Skip the commit if no edits. If edits were made, commit them with a descriptive message.

---

## Task 7.5 — Extend `preflight.sh` to all 8 guards

**Files:**
- Modify: `ios/Scripts/preflight.sh`

- [ ] **Step 1: Rewrite the script**

```bash
#!/usr/bin/env bash
# iOS preflight — fail CI on policy violations.
# Spec §9.8 — eight guards, each a separate section for clear failure attribution.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

STATUS=0
fail()  { echo "PREFLIGHT FAIL: $1" >&2; STATUS=1; }
pass()  { echo "OK: $1"; }
section() { echo; echo "=== $1 ==="; }

# ---------------------------------------------------------------------------
section "1/8 — Codegen freshness (source SHA256 embedded in generated Swift)"
check_hash_in_file() {
    local source_file="$1"; local generated_file="$2"
    local expected; expected="$(shasum -a 256 "$source_file" | awk '{print $1}')"
    if ! grep -q "$expected" "$generated_file"; then
        fail "$generated_file is stale vs $source_file. Run ios/Scripts/generate-ipa-mapping.sh and commit."
    else
        pass "$generated_file fresh against $source_file"
    fi
}
check_hash_in_file "shared-config/default-mappings.json"        "ios/IPACore/Sources/IPACore/IPAMapping.swift"
check_hash_in_file "companion-app/src/data/ipa-symbols.json"    "ios/IPACore/Sources/IPACore/SymbolReferenceData.swift"
check_hash_in_file "companion-app/src/data/ipa-names.ts"        "ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift"

# ---------------------------------------------------------------------------
section "2/8 — Privacy manifest present + declares no tracking + CA92.1"
for target in IPAKeyboardApp IPAKeyboardExtension; do
    privacy="ios/$target/PrivacyInfo.xcprivacy"
    [[ -f "$privacy" ]] || { fail "$privacy missing"; continue; }
    if ! grep -q '<key>NSPrivacyTracking</key>' "$privacy" || ! grep -A1 '<key>NSPrivacyTracking</key>' "$privacy" | grep -q '<false/>'; then
        fail "$privacy must declare NSPrivacyTracking=false"
    fi
    if ! grep -q 'CA92.1' "$privacy"; then
        fail "$privacy must declare CA92.1 for UserDefaults"
    fi
    pass "$privacy declares no tracking + CA92.1"
done

# ---------------------------------------------------------------------------
section "3/8 — Required-reason API drift (UserDefaults ↔ CA92.1)"
for target in IPAKeyboardApp IPAKeyboardExtension; do
    uses_ud=0
    if grep -RqE 'UserDefaults\.' "ios/$target/"; then uses_ud=1; fi
    declared=0
    if grep -q 'CA92.1' "ios/$target/PrivacyInfo.xcprivacy" 2>/dev/null; then declared=1; fi
    if [[ $uses_ud -eq 1 && $declared -eq 0 ]]; then
        fail "$target uses UserDefaults but does not declare CA92.1"
    elif [[ $uses_ud -eq 1 ]]; then
        pass "$target uses UserDefaults and declares CA92.1"
    else
        pass "$target does not use UserDefaults"
    fi
done

# ---------------------------------------------------------------------------
section "4/8 — Entitlements scrub (no App Group / network / Full Access)"
for target in IPAKeyboardApp IPAKeyboardExtension; do
    ent="ios/$target/$target.entitlements"
    [[ -f "$ent" ]] || { fail "$ent missing"; continue; }
    if grep -qE 'com.apple.security.application-groups|com.apple.security.network|com.apple.security.personal-information|keychain-access-groups' "$ent"; then
        fail "$ent declares a forbidden capability"
    else
        pass "$ent is clean"
    fi
done

# ---------------------------------------------------------------------------
section "5/8 — No network code anywhere in ios/"
if grep -RnE 'URLSession|NWConnection|\.network' ios/ \
     --include='*.swift' \
     --exclude-dir='Tests' \
     --exclude-dir='__Snapshots__' 2>/dev/null; then
    fail "Network-adjacent symbols found in iOS sources"
else
    pass "No network-adjacent symbols in ios/ Swift sources"
fi

# ---------------------------------------------------------------------------
section "6/8 — Forbidden APIs inside keyboard extension"
forbidden_extension() {
    local label="$1"; local pattern="$2"
    if grep -RnE "$pattern" ios/IPAKeyboardExtension/ 2>/dev/null; then
        fail "$label found inside keyboard extension (forbidden)"
    else
        pass "No $label in keyboard extension"
    fi
}
forbidden_extension "UIPasteboard"   'UIPasteboard'
forbidden_extension "CLLocation"     'CLLocation|CLLocationManager'
forbidden_extension "AVAudio*"       'AVAudioSession|AVAudioEngine|AVAudioRecorder'
forbidden_extension "tracking IDs"   'ASIdentifierManager|advertisingIdentifier|identifierForVendor'
forbidden_extension "Contacts"       'CNContact'
forbidden_extension "Photos"         'PHPhotoLibrary'

# ---------------------------------------------------------------------------
section "7/8 — Extension binary size within 5% of baseline"
BASELINE_FILE="ios/Scripts/baseline-sizes.json"
if [[ ! -f "$BASELINE_FILE" ]]; then
    fail "$BASELINE_FILE missing — run ios/Scripts/update-baseline.sh to seed it"
else
    # Build the extension for device (arm64) in Release so the baseline is meaningful.
    ARCHIVE_DIR="$(mktemp -d)"
    xcodebuild -project ios/IPAKeyboard.xcodeproj \
               -scheme IPAKeyboardApp \
               -configuration Release \
               -destination 'generic/platform=iOS' \
               -archivePath "$ARCHIVE_DIR/app.xcarchive" \
               archive -quiet 2>/dev/null \
        || fail "archive build failed (cannot measure size)"
    BIN="$ARCHIVE_DIR/app.xcarchive/Products/Applications/IPAKeyboardApp.app/PlugIns/IPAKeyboardExtension.appex/IPAKeyboardExtension"
    if [[ -f "$BIN" ]]; then
        STRIPPED="$(mktemp)"
        strip -x -o "$STRIPPED" "$BIN" 2>/dev/null || cp "$BIN" "$STRIPPED"
        ACTUAL=$(stat -f%z "$STRIPPED")
        EXPECTED=$(jq '.extension_stripped_arm64' "$BASELINE_FILE")
        if [[ "$EXPECTED" == "null" || -z "$EXPECTED" ]]; then
            fail "$BASELINE_FILE missing 'extension_stripped_arm64' key"
        else
            DELTA=$(awk -v a=$ACTUAL -v e=$EXPECTED 'BEGIN{printf "%.4f", (a-e)/e}')
            OUT_OF_BOUND=$(awk -v d=$DELTA 'BEGIN{print (d<-0.05 || d>0.05) ? "1":"0"}')
            if [[ "$OUT_OF_BOUND" == "1" ]]; then
                fail "Extension size ${ACTUAL}B vs baseline ${EXPECTED}B (delta ${DELTA}, outside ±5%). If intentional: ios/Scripts/update-baseline.sh."
            else
                pass "Extension size ${ACTUAL}B within ±5% of baseline ${EXPECTED}B (delta ${DELTA})"
            fi
        fi
    else
        fail "Built extension binary not found at $BIN"
    fi
fi

# ---------------------------------------------------------------------------
section "8/8 — Symbol round-trip (via IPACore unit tests)"
if ( cd ios/IPACore && swift test --filter IPAMappingTests --filter CodegenIntegrityTests >/dev/null 2>&1 ); then
    pass "IPAMapping + CodegenIntegrity tests green"
else
    fail "IPACore tests failed — run 'cd ios/IPACore && swift test' to investigate"
fi

# ---------------------------------------------------------------------------
echo
if [[ $STATUS -eq 0 ]]; then
    echo "ALL PREFLIGHT CHECKS PASSED"
else
    echo "PREFLIGHT FAILED"
fi
exit $STATUS
```

- [ ] **Step 2: Write `update-baseline.sh`**

`ios/Scripts/update-baseline.sh`:

```bash
#!/usr/bin/env bash
# Rebuild the extension for arm64 Release, strip symbols, record size as the new baseline.
# Intended to be run intentionally and committed as part of the PR that justifies the change.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

ARCHIVE_DIR="$(mktemp -d)"
xcodebuild -project ios/IPAKeyboard.xcodeproj \
           -scheme IPAKeyboardApp \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath "$ARCHIVE_DIR/app.xcarchive" \
           archive

BIN="$ARCHIVE_DIR/app.xcarchive/Products/Applications/IPAKeyboardApp.app/PlugIns/IPAKeyboardExtension.appex/IPAKeyboardExtension"
STRIPPED="$(mktemp)"
strip -x -o "$STRIPPED" "$BIN" 2>/dev/null || cp "$BIN" "$STRIPPED"
SIZE=$(stat -f%z "$STRIPPED")

BASELINE_FILE="ios/Scripts/baseline-sizes.json"
jq --argjson size "$SIZE" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{extension_stripped_arm64: $size, recorded_at: $date}' \
    <<<'{}' > "$BASELINE_FILE"

echo "Updated $BASELINE_FILE to $SIZE bytes"
```

- [ ] **Step 3: Make both executable and seed the baseline**

```bash
chmod +x ios/Scripts/preflight.sh ios/Scripts/update-baseline.sh
ios/Scripts/update-baseline.sh
```
Expected: `Updated ios/Scripts/baseline-sizes.json to <size> bytes`.
Expect roughly 400 KB – 2 MB; if it's > 4 MB something is wrong (likely an image slipped in).

- [ ] **Step 4: Run the full preflight**

```bash
ios/Scripts/preflight.sh
```
Expected: sequence of `OK:` lines, ending with `ALL PREFLIGHT CHECKS PASSED`.

Common failures to expect on the first run:
- If the archive build fails because signing isn't set up for device, skip step 7 locally by running preflight with `SKIP_SIZE_CHECK=1 ios/Scripts/preflight.sh` — this is accepted on dev machines. Production CI will run it with signing set up.
- If a CA92.1 mismatch is reported, re-check `PrivacyInfo.xcprivacy` contents.

- [ ] **Step 5: Commit**

```bash
git add ios/Scripts/preflight.sh ios/Scripts/update-baseline.sh ios/Scripts/baseline-sizes.json
git commit -m "ios: preflight.sh implements all 8 guards from spec §9.8

Each guard is its own section; failures name the specific violation.
Size guard: ±5% of baseline in baseline-sizes.json; update-baseline.sh
regenerates the baseline when an intentional bump ships."
```

---

## Task 7.6 — Write submission-prep docs

**Files:**
- Create: `docs/ios/submission-checklist.md`
- Create: `docs/ios/manual-test-checklist.md`
- Create: `docs/ios/review-notes.md`
- Create: `docs/ios/README.md`

- [ ] **Step 1: `docs/ios/submission-checklist.md`**

Content (verbatim from spec §9.7 with one-line header):

```markdown
# iOS Submission Checklist

Re-run before every App Store submission. Each item must be ticked in the PR that produces the build.

- [ ] `RequestsOpenAccess = NO` in extension `Info.plist`
- [ ] `IsASCIICapable = YES` in extension `Info.plist`
- [ ] `PrivacyInfo.xcprivacy` present in both targets, declares `CA92.1` for `UserDefaults`
- [ ] No network / App Group / Full Access entitlements
- [ ] CI preflight green: codegen fresh, forbidden-APIs grep clean, extension size within 5% of baseline
- [ ] All unit + snapshot + UI tests green
- [ ] Manual checklist signed off (see `manual-test-checklist.md`)
- [ ] Apple privacy-report tool run against the built app; output matches the manifest
- [ ] TestFlight ≥1 week; ≥1 tester on iPhone SE, ≥1 on iPad; no blocking regressions
- [ ] Screenshots captured: iPhone 6.7" + 6.1"; iPad 12.9" + 11"
- [ ] App Store Connect: description, keywords, support URL, privacy policy URL populated
- [ ] Distribution-signed build uploaded via Transporter or `xcrun altool`
```

- [ ] **Step 2: `docs/ios/manual-test-checklist.md`**

Content (from spec §8.4):

```markdown
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
```

- [ ] **Step 3: `docs/ios/review-notes.md`**

Content from spec §9.6 (verbatim review notes, plus header explaining what to paste where).

```markdown
# App Store Review — Notes for Reviewer

Paste this text into App Store Connect → App Review Information → Notes (required field) for every submission.

---

IPA Keyboard is an alternate iOS keyboard for typing IPA (International
Phonetic Alphabet) symbols, for linguistics students and researchers.

Fully offline — no network, no accounts, no data collection, no analytics.

PERMISSIONS
  • RequestsOpenAccess: NO — the keyboard does not request Full Access.
  • No App Group. No network entitlement. No sandbox exceptions.
  • Privacy manifest declares no tracking, no collection, no tracking domains.

HOW TO TEST
  1. Install, open the app.
  2. On the Setup tab, tap "Open Settings".
  3. In Settings: General → Keyboard → Keyboards → Add New Keyboard → IPA Keyboard.
     (Do NOT enable Full Access — the keyboard does not use it.)
  4. Return to our app. Tap the "Try it here" field, press 🌐, switch to IPA Keyboard.
  5. Long-press any of the dotted letters (a e i o u t s d c n z) to choose an IPA variant.
  6. Verify typing works in any app with a text field.

The IPA symbol set is standard Unicode used in linguistics textbooks; it is a
subset of the Latin Extended IPA block.
```

- [ ] **Step 4: `docs/ios/README.md`**

One-pager entry doc pointing to the other three + the spec + PLAN.md.

```markdown
# iOS Sub-project — `ios/`

An iOS App Store app. Third-party keyboard extension + minimal container app.

**Design spec:** `docs/superpowers/specs/2026-04-21-ios-ipa-keyboard-design.md`
**Plan:** [`ios/PLAN.md`](../../ios/PLAN.md)
**Submission checklist:** [`submission-checklist.md`](submission-checklist.md)
**Manual test checklist:** [`manual-test-checklist.md`](manual-test-checklist.md)
**Reviewer notes template:** [`review-notes.md`](review-notes.md)

## Build locally

```
cd ios/
open IPAKeyboard.xcodeproj
```

Scheme: `IPAKeyboardApp`. Run on any iOS 16+ simulator.

## Run preflight

```
./Scripts/preflight.sh
```

## Regenerate codegen after mapping changes

```
./Scripts/generate-ipa-mapping.sh
```

Commit the generated `IPAMapping.swift`, `SymbolReferenceData.swift`, and `LocalizedSymbolNames.swift`.
```

- [ ] **Step 5: Commit**

```bash
git add docs/ios/
git commit -m "ios: submission + manual-test + review-notes docs

Pulled out of the spec so submissions can use them as a working checklist
without dragging the whole spec open each time."
```

---

## Phase 7 exit checklist

- [ ] Both `.entitlements` files contain only `<dict/>`; grep confirms no forbidden capability keys
- [ ] Extension `Info.plist` contains all required keys from spec §9.3 verbatim
- [ ] `PrivacyInfo.xcprivacy` present in both targets (identical content, CA92.1 declared)
- [ ] Forbidden-API grep is clean in `ios/IPAKeyboardExtension/`
- [ ] `ios/Scripts/preflight.sh` exits 0 end-to-end (size check may be skipped locally if no device signing)
- [ ] `ios/Scripts/baseline-sizes.json` committed and reasonable (< 4 MB)
- [ ] `docs/ios/submission-checklist.md`, `docs/ios/manual-test-checklist.md`, `docs/ios/review-notes.md`, `docs/ios/README.md` all present
- [ ] `xcodebuild archive` succeeds (even if signing is personal-team) — this proves the privacy manifest + entitlements are consistent

When all boxes are ticked, tick Phase 7 in `ios/PLAN.md` and move to Phase 8.
