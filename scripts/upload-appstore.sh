#!/bin/bash
set -euo pipefail

# Upload the IPA Keyboard companion app to Mac App Store Connect.
#
# Usage:
#   bash scripts/upload-appstore.sh <path-to-.app>
#
# Prerequisites:
#   - App must be signed with "3rd Party Mac Developer Application" certificate
#   - "3rd Party Mac Developer Installer" certificate installed for .pkg signing
#
# Authentication (set one of these pairs):
#
#   Option A — App Store Connect API Key (recommended for CI):
#     MAS_API_KEY_ID       — API key ID
#     MAS_API_KEY_ISSUER   — Issuer ID (UUID from App Store Connect)
#     MAS_API_KEY_PATH     — Path to .p8 key file
#
#   Option B — Apple ID:
#     MAS_APPLE_ID         — Apple ID email
#     MAS_PASSWORD         — App-specific password (use @keychain:AC_PASSWORD)
#
# Signing identities (required):
#   MAS_APP_IDENTITY       — "3rd Party Mac Developer Application: Name (TEAMID)"
#   MAS_INSTALLER_IDENTITY — "3rd Party Mac Developer Installer: Name (TEAMID)"

APP_PATH="${1:-}"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-.app>"
    echo ""
    echo "Example:"
    echo "  bash $0 companion-app/src-tauri/target/release/bundle/macos/IPA\\ Keyboard.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: '$APP_PATH' does not exist or is not a directory"
    exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
TEMP_DIR="$(mktemp -d)"
if [ ! -d "$TEMP_DIR" ]; then
    echo "Error: Failed to create temp directory"
    exit 1
fi
PKG_PATH="$TEMP_DIR/${APP_NAME}.pkg"

trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== Uploading $APP_NAME to Mac App Store ==="

# --- Step 1: Verify signing identity ---
echo ""
echo "--- Step 1: Verifying code signature ---"

SIGNING_INFO="$(codesign -d --verbose=2 "$APP_PATH" 2>&1)"

if ! echo "$SIGNING_INFO" | grep -q "3rd Party Mac Developer"; then
    echo "Error: App is not signed with '3rd Party Mac Developer Application' certificate."
    echo "App Store requires '3rd Party Mac Developer Application' (not 'Developer ID')."
    echo ""
    echo "Detected signing:"
    echo "$SIGNING_INFO" | grep "Authority" || echo "  (no signing authority found)"
    echo ""
    echo "To fix: rebuild with MAS_APP_IDENTITY set, or re-sign with:"
    echo "  codesign --force --sign \"3rd Party Mac Developer Application: ...\" \\"
    echo "    --entitlements Entitlements.plist --options runtime \"$APP_PATH\""
    exit 1
fi

if ! codesign --verify --deep --strict "$APP_PATH" 2>&1; then
    echo "Error: Signature verification failed"
    exit 1
fi
echo "Signature OK (3rd Party Mac Developer)"

# Check for App Sandbox entitlement (required for App Store)
ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_PATH" 2>&1)"
if ! echo "$ENTITLEMENTS" | grep -q "com.apple.security.app-sandbox"; then
    echo "Error: App Sandbox entitlement not found."
    echo "Mac App Store requires com.apple.security.app-sandbox = true"
    exit 1
fi
echo "App Sandbox entitlement: present"

# --- Step 2: Create installer package ---
echo ""
echo "--- Step 2: Creating installer package (.pkg) ---"

MAS_INSTALLER_IDENTITY="${MAS_INSTALLER_IDENTITY:-}"
if [ -z "$MAS_INSTALLER_IDENTITY" ]; then
    echo "Error: MAS_INSTALLER_IDENTITY not set."
    echo "Set it to your installer certificate, e.g.:"
    echo "  export MAS_INSTALLER_IDENTITY=\"3rd Party Mac Developer Installer: Your Name (TEAMID)\""
    exit 1
fi

productbuild \
    --component "$APP_PATH" /Applications \
    --sign "$MAS_INSTALLER_IDENTITY" \
    "$PKG_PATH"

if [ ! -f "$PKG_PATH" ]; then
    echo "Error: Failed to create .pkg"
    exit 1
fi
echo "Package: $PKG_PATH ($(du -h "$PKG_PATH" | cut -f1))"

# --- Step 3: Validate package ---
echo ""
echo "--- Step 3: Validating package ---"

UPLOAD_ARGS=()

if [ -n "${MAS_API_KEY_ID:-}" ] && [ -n "${MAS_API_KEY_ISSUER:-}" ]; then
    echo "Auth: App Store Connect API Key"
    if [ -z "${MAS_API_KEY_PATH:-}" ]; then
        echo "Error: MAS_API_KEY_PATH is required when using API Key auth"
        exit 1
    fi
    if [ ! -f "$MAS_API_KEY_PATH" ]; then
        echo "Error: API key file not found: $MAS_API_KEY_PATH"
        exit 1
    fi
    UPLOAD_ARGS+=(
        --apiKey "$MAS_API_KEY_ID"
        --apiIssuer "$MAS_API_KEY_ISSUER"
    )
elif [ -n "${MAS_APPLE_ID:-}" ]; then
    echo "Auth: Apple ID"
    MAS_PASSWORD="${MAS_PASSWORD:-@keychain:AC_PASSWORD}"
    UPLOAD_ARGS+=(
        --username "$MAS_APPLE_ID"
        --password "$MAS_PASSWORD"
    )
else
    echo "Error: No authentication credentials configured."
    echo ""
    echo "Set one of:"
    echo "  API Key (recommended):"
    echo "    MAS_API_KEY_ID, MAS_API_KEY_ISSUER, MAS_API_KEY_PATH"
    echo "  Apple ID:"
    echo "    MAS_APPLE_ID, MAS_PASSWORD"
    exit 1
fi

echo "Validating..."
if ! xcrun altool --validate-app \
    --file "$PKG_PATH" \
    --type macos \
    "${UPLOAD_ARGS[@]}" 2>&1; then
    echo ""
    echo "Error: Validation failed. Fix the issues above before uploading."
    exit 1
fi
echo "Validation passed"

# --- Step 4: Upload to App Store Connect ---
echo ""
echo "--- Step 4: Uploading to App Store Connect ---"

echo "Uploading... (this may take several minutes)"
if ! xcrun altool --upload-app \
    --file "$PKG_PATH" \
    --type macos \
    "${UPLOAD_ARGS[@]}" 2>&1; then
    echo ""
    echo "Error: Upload failed."
    echo "You can also upload manually using Transporter.app:"
    echo "  1. Open Transporter (from App Store)"
    echo "  2. Drag $PKG_PATH into Transporter"
    echo "  3. Click Deliver"
    exit 1
fi

echo ""
echo "=== Upload complete ==="
echo "Package uploaded to App Store Connect."
echo ""
echo "Next steps:"
echo "  1. Go to https://appstoreconnect.apple.com"
echo "  2. Select your app (com.minhphan.ipa-keyboard)"
echo "  3. Under the build section, select the uploaded build"
echo "  4. Add review notes explaining entitlement justifications:"
echo "     - allow-jit: Required by Tauri framework's WKWebView for JavaScript execution"
echo "     - disable-library-validation: Required for Tauri's bundled plugin loading"
echo "  5. Submit for review"
