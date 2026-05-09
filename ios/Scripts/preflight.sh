#!/usr/bin/env bash
# iOS preflight — fail CI on policy violations.
# Spec §9.8 — eight guards, each a separate section for clear failure attribution.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

STATUS=0
fail()    { echo "PREFLIGHT FAIL: $1" >&2; STATUS=1; }
pass()    { echo "OK: $1"; }
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
if [[ "${SKIP_SIZE_CHECK:-0}" == "1" ]]; then
    echo "SKIP: SKIP_SIZE_CHECK=1 set (use on dev machines without device signing)"
else
    BASELINE_FILE="ios/Scripts/baseline-sizes.json"
    if [[ ! -f "$BASELINE_FILE" ]]; then
        fail "$BASELINE_FILE missing — run ios/Scripts/update-baseline.sh to seed it"
    else
        ARCHIVE_DIR="$(mktemp -d)"
        if xcodebuild -project ios/IPAKeyboard.xcodeproj \
                      -scheme IPAKeyboardApp \
                      -configuration Release \
                      -destination 'generic/platform=iOS' \
                      -archivePath "$ARCHIVE_DIR/app.xcarchive" \
                      -allowProvisioningUpdates \
                      archive -quiet 2>/dev/null; then
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
        else
            fail "archive build failed (cannot measure size). Set SKIP_SIZE_CHECK=1 to bypass on dev machines without device signing."
        fi
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
