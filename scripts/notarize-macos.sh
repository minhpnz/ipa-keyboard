#!/bin/bash
set -euo pipefail

# Notarize a macOS app bundle or DMG for distribution.
#
# Usage:
#   bash scripts/notarize-macos.sh <path-to-.app-or-.dmg>
#
# Authentication (set one of these pairs):
#
#   Option A — App Store Connect API Key (recommended for CI):
#     NOTARIZE_API_KEY_ID     — API key ID (e.g. "XXXXXXXXXX")
#     NOTARIZE_API_KEY_ISSUER — Issuer ID (UUID from App Store Connect)
#     NOTARIZE_API_KEY_PATH   — Path to .p8 key file (required)
#
#   Option B — Apple ID (interactive / local):
#     NOTARIZE_APPLE_ID       — Apple ID email
#     NOTARIZE_TEAM_ID        — Team ID (e.g. "XXXXXXXXXX")
#     NOTARIZE_PASSWORD       — App-specific password (use @keychain:AC_PASSWORD)

APP_PATH="${1:-}"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-.app-or-.dmg>"
    echo ""
    echo "Examples:"
    echo "  bash $0 ime-core/macos/build/IPAKeyboard.app"
    echo "  bash $0 package-release/IPA_Keyboard_0.1.0_universal.dmg"
    exit 1
fi

# Detect input type. .app bundles need hardened-runtime + zip wrapping;
# .dmg files are submitted directly and skip the runtime check.
if [ -d "$APP_PATH" ]; then
    INPUT_TYPE="app"
elif [ -f "$APP_PATH" ] && [[ "$APP_PATH" == *.dmg ]]; then
    INPUT_TYPE="dmg"
else
    echo "Error: '$APP_PATH' must be a .app directory or a .dmg file"
    exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
TEMP_DIR="$(mktemp -d)"
if [ ! -d "$TEMP_DIR" ]; then
    echo "Error: Failed to create temp directory"
    exit 1
fi
LOG_FILE="$TEMP_DIR/notarize.log"

trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== Notarizing $APP_NAME ($INPUT_TYPE) ==="

# --- Step 1: Verify code signature ---
echo ""
echo "--- Step 1: Verifying code signature ---"
if ! codesign --verify --deep --strict "$APP_PATH" 2>&1; then
    echo "Error: '$APP_NAME' is not properly signed."
    echo "Run build-release.sh with APPLE_SIGNING_IDENTITY set first."
    exit 1
fi

if [ "$INPUT_TYPE" = "app" ]; then
    # Hardened runtime is required for notarization of executables.
    CODESIGN_INFO="$(codesign -d --verbose=2 "$APP_PATH" 2>&1)"
    if ! echo "$CODESIGN_INFO" | grep -q "flags=.*runtime"; then
        echo "Error: Hardened runtime is not enabled."
        echo "Notarization requires --options runtime during signing."
        exit 1
    fi
    echo "Signature OK (hardened runtime enabled)"
else
    echo "Signature OK (DMG)"
fi

# --- Step 2: Prepare submission payload ---
echo ""
echo "--- Step 2: Preparing submission payload ---"
if [ "$INPUT_TYPE" = "app" ]; then
    SUBMIT_PATH="$TEMP_DIR/$(basename "$APP_PATH" .app).zip"
    ditto -c -k --keepParent "$APP_PATH" "$SUBMIT_PATH"
    if ! unzip -t "$SUBMIT_PATH" >/dev/null 2>&1; then
        echo "Error: Created ZIP archive is corrupt"
        exit 1
    fi
    echo "Archive: $SUBMIT_PATH ($(du -h "$SUBMIT_PATH" | cut -f1))"
else
    # notarytool accepts .dmg directly — no wrapping needed.
    SUBMIT_PATH="$APP_PATH"
    echo "Submitting DMG directly: $SUBMIT_PATH ($(du -h "$SUBMIT_PATH" | cut -f1))"
fi

# --- Step 3: Submit to Apple ---
echo ""
echo "--- Step 3: Submitting to Apple notary service ---"

NOTARIZE_ARGS=()

if [ -n "${NOTARIZE_API_KEY_ID:-}" ] && [ -n "${NOTARIZE_API_KEY_ISSUER:-}" ]; then
    # API Key authentication (recommended)
    echo "Auth: App Store Connect API Key"

    if [ -z "${NOTARIZE_API_KEY_PATH:-}" ]; then
        echo "Error: NOTARIZE_API_KEY_PATH is required when using API Key auth"
        exit 1
    fi
    if [ ! -f "$NOTARIZE_API_KEY_PATH" ]; then
        echo "Error: API key file not found: $NOTARIZE_API_KEY_PATH"
        exit 1
    fi

    NOTARIZE_ARGS+=(
        --key-id "$NOTARIZE_API_KEY_ID"
        --issuer "$NOTARIZE_API_KEY_ISSUER"
        --key "$NOTARIZE_API_KEY_PATH"
    )
elif [ -n "${NOTARIZE_APPLE_ID:-}" ] && [ -n "${NOTARIZE_TEAM_ID:-}" ]; then
    # Apple ID authentication
    # Note: Prefer API Key auth for CI. Apple ID auth uses @keychain: for passwords.
    echo "Auth: Apple ID"

    NOTARIZE_PASSWORD="${NOTARIZE_PASSWORD:-@keychain:AC_PASSWORD}"
    if [ "$NOTARIZE_PASSWORD" = "@keychain:AC_PASSWORD" ]; then
        echo "  Using keychain password (AC_PASSWORD). Set NOTARIZE_PASSWORD to override."
    fi

    NOTARIZE_ARGS+=(
        --apple-id "$NOTARIZE_APPLE_ID"
        --team-id "$NOTARIZE_TEAM_ID"
        --password "$NOTARIZE_PASSWORD"
    )
else
    echo "Error: No notarization credentials configured."
    echo ""
    echo "Set one of:"
    echo "  API Key (recommended):"
    echo "    NOTARIZE_API_KEY_ID, NOTARIZE_API_KEY_ISSUER, NOTARIZE_API_KEY_PATH"
    echo "  Apple ID:"
    echo "    NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, NOTARIZE_PASSWORD"
    exit 1
fi

echo "Submitting... (this may take several minutes)"
SUBMIT_OUTPUT="$(xcrun notarytool submit "$SUBMIT_PATH" \
    "${NOTARIZE_ARGS[@]}" \
    --wait --timeout 60m 2>&1)" || {
    echo "Error: Notarization submission failed"
    echo "$SUBMIT_OUTPUT"
    exit 1
}
echo "$SUBMIT_OUTPUT"

# Extract and log submission ID for audit trail
SUBMISSION_ID="$(echo "$SUBMIT_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || echo "unknown")"
echo ""
echo "Submission ID: $SUBMISSION_ID"
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $APP_NAME submission=$SUBMISSION_ID" >> "$LOG_FILE"

# Check submission status
if echo "$SUBMIT_OUTPUT" | grep -qi "invalid\|rejected"; then
    echo "Error: Notarization was rejected by Apple"
    echo "Check the submission log: xcrun notarytool log $SUBMISSION_ID ${NOTARIZE_ARGS[*]}"
    exit 1
fi

# --- Step 4: Staple the notarization ticket ---
echo ""
echo "--- Step 4: Stapling notarization ticket ---"
if ! xcrun stapler staple "$APP_PATH"; then
    echo "Error: Failed to staple notarization ticket"
    echo "The app was notarized but the ticket could not be attached."
    echo "Try again: xcrun stapler staple '$APP_PATH'"
    exit 1
fi

# --- Step 5: Final verification ---
echo ""
echo "--- Step 5: Verifying notarization ---"

# Validate the stapled ticket
if ! xcrun stapler validate "$APP_PATH" 2>&1; then
    echo "Error: Stapled ticket validation failed"
    exit 1
fi

# Gatekeeper assessment (use the policy that matches the input type)
if [ "$INPUT_TYPE" = "app" ]; then
    SPCTL_TYPE="execute"
else
    SPCTL_TYPE="open --context context:primary-signature"
fi
# shellcheck disable=SC2086
SPCTL_OUTPUT="$(spctl --assess --type $SPCTL_TYPE --verbose=2 "$APP_PATH" 2>&1)" || true
echo "$SPCTL_OUTPUT"
if echo "$SPCTL_OUTPUT" | grep -qi "rejected\|denied"; then
    echo "Warning: Gatekeeper rejected '$APP_NAME'. Check signing identity and entitlements."
fi

echo ""
echo "=== Notarization complete ==="
echo "Submission ID: $SUBMISSION_ID"
echo "Ready for distribution: $APP_PATH"
