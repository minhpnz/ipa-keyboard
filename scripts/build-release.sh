#!/bin/bash
# =============================================================================
# IPA Keyboard - Release Build Script
# Builds universal macOS app, signs, notarizes, and packages for distribution.
#
# Usage:
#   bash scripts/build-release.sh                # Sign + notarize (production)
#   bash scripts/build-release.sh --unsigned     # Skip signing (dev)
#
# Required env vars when signing (unset = error, unless --unsigned):
#   APPLE_SIGNING_IDENTITY    "Developer ID Application: <Name> (TEAM_ID)"
#   NOTARIZE_API_KEY_ID       App Store Connect API Key ID
#   NOTARIZE_API_KEY_ISSUER   Issuer UUID
#   NOTARIZE_API_KEY_PATH     Path to .p8 file (NEVER inside the repo)
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.1.1"
RELEASE_DIR="$REPO_ROOT/package-release"
BINARIES_DIR="$REPO_ROOT/companion-app/src-tauri/binaries"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# Parse args
# =============================================================================
SIGN_AND_NOTARIZE=true
for arg in "$@"; do
    case "$arg" in
        --unsigned|--dev)
            SIGN_AND_NOTARIZE=false
            ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *)
            error "Unknown argument: $arg (allowed: --unsigned, --dev, --help)"
            ;;
    esac
done

# =============================================================================
# Pre-flight checks
# =============================================================================
# Source NVM if present so we pick up the user's selected Node version
# (non-interactive shells don't auto-load .zshrc/.bashrc).
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1091
    \. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
fi

log "Checking dependencies..."
command -v cargo >/dev/null 2>&1 || error "cargo not found. Install Rust first."
command -v npm >/dev/null 2>&1 || error "npm not found. Install Node.js first."
command -v lipo >/dev/null 2>&1 || error "lipo not found. Xcode CLI tools required."
command -v hdiutil >/dev/null 2>&1 || error "hdiutil not found. macOS required."

if [ "$SIGN_AND_NOTARIZE" = true ]; then
    : "${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY must be set when signing. Use --unsigned to skip.}"
    : "${NOTARIZE_API_KEY_ID:?NOTARIZE_API_KEY_ID must be set when signing. Use --unsigned to skip.}"
    : "${NOTARIZE_API_KEY_ISSUER:?NOTARIZE_API_KEY_ISSUER must be set when signing. Use --unsigned to skip.}"
    : "${NOTARIZE_API_KEY_PATH:?NOTARIZE_API_KEY_PATH must be set when signing. Use --unsigned to skip.}"
    [ -f "$NOTARIZE_API_KEY_PATH" ] || error "NOTARIZE_API_KEY_PATH file not found: $NOTARIZE_API_KEY_PATH"
    case "$NOTARIZE_API_KEY_PATH" in
        "$REPO_ROOT"/*) error "NOTARIZE_API_KEY_PATH points inside the repo ($NOTARIZE_API_KEY_PATH). Move the .p8 outside the repo." ;;
    esac
    command -v xcrun >/dev/null 2>&1 || error "xcrun not found. Xcode required."
    command -v codesign >/dev/null 2>&1 || error "codesign not found. Xcode CLI tools required."
    log "Signing identity: $APPLE_SIGNING_IDENTITY"
fi

if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
    log "Adding aarch64-apple-darwin target..."
    rustup target add aarch64-apple-darwin
fi
if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
    log "Adding x86_64-apple-darwin target..."
    rustup target add x86_64-apple-darwin
fi

# =============================================================================
# Setup directories
# =============================================================================
log "Setting up directories..."
mkdir -p "$BINARIES_DIR"
mkdir -p "$RELEASE_DIR"

rm -f "$RELEASE_DIR"/*.dmg
rm -f "$RELEASE_DIR"/README*.txt
rm -f "$RELEASE_DIR"/INSTALL*.txt
rm -f "$RELEASE_DIR"/fix-gatekeeper.command

# =============================================================================
# Build daemon for both architectures
# =============================================================================
log "Building daemon for Apple Silicon (arm64)..."
cargo build -p ipa-keyboard-daemon --release --target aarch64-apple-darwin \
    --manifest-path "$REPO_ROOT/Cargo.toml"

log "Building daemon for Intel (x86_64)..."
cargo build -p ipa-keyboard-daemon --release --target x86_64-apple-darwin \
    --manifest-path "$REPO_ROOT/Cargo.toml"

# =============================================================================
# Create universal daemon binary
# =============================================================================
log "Creating universal daemon binary..."
lipo -create \
    "$REPO_ROOT/target/aarch64-apple-darwin/release/ipa-keyboard-daemon" \
    "$REPO_ROOT/target/x86_64-apple-darwin/release/ipa-keyboard-daemon" \
    -output "$BINARIES_DIR/ipa-keyboard-daemon-universal-apple-darwin"
chmod +x "$BINARIES_DIR/ipa-keyboard-daemon-universal-apple-darwin"

cp "$REPO_ROOT/target/aarch64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-aarch64-apple-darwin"
cp "$REPO_ROOT/target/x86_64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-x86_64-apple-darwin"

# =============================================================================
# Build Tauri app (universal)
# =============================================================================
log "Installing frontend dependencies (npm ci — deterministic, matches lockfile)..."
cd "$REPO_ROOT/companion-app"
# npm ci is required for release builds — it pins to package-lock.json and
# fully replaces node_modules. Plain `npm install` has produced corrupt
# installs (empty dist/ directories) and version drift from Rust crates.
npm ci

log "Building universal Tauri app..."
# Node 14+ required (Tauri 2 CLI uses optional chaining). Bail early.
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 14 ]; then
    error "Node.js >= 14 required (found: $(node --version 2>/dev/null || echo 'none'))"
fi

# Clean prior bundle so a failed/skipped Tauri build can't leave us signing
# a stale artifact (this happened once — caught by 9-day-old timestamps).
APP_BUNDLE_DIR="$REPO_ROOT/companion-app/src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app"
rm -rf "$APP_BUNDLE_DIR"

# No || { warn } — let set -e kill us if Tauri fails. Anything less hides
# real errors (Node/Rust/permission/CSP).
#
# Tauri 2's bundler auto-detects APPLE_SIGNING_IDENTITY from env and tries
# to codesign mid-bundle, which fails on the xattrs cargo leaves on the
# fresh binary ("resource fork, Finder information, or similar detritus
# not allowed"). Unset signing env in a subshell so Tauri only builds —
# we strip xattrs and sign ourselves below.
(
    unset APPLE_SIGNING_IDENTITY APPLE_CERTIFICATE APPLE_CERTIFICATE_PASSWORD \
          APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID APPLE_API_ISSUER APPLE_API_KEY
    npm run tauri build -- --target universal-apple-darwin
)

APP_PATH=""
if [ -d "$APP_BUNDLE_DIR" ]; then
    APP_PATH="$APP_BUNDLE_DIR"
elif [ -d "$REPO_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app" ]; then
    APP_PATH="$REPO_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"
else
    error "Could not find built .app bundle after Tauri build"
fi

log "Found app at: $APP_PATH"

ARCH_INFO=$(file "$APP_PATH/Contents/MacOS/ipa-keyboard" 2>/dev/null || echo "unknown")
if echo "$ARCH_INFO" | grep -q "universal"; then
    log "Verified: Universal binary (Intel + Apple Silicon)"
else
    warn "Binary may not be universal: $ARCH_INFO"
fi

# =============================================================================
# Sign + notarize + DMG
#
# Architecture note: the daemon is statically linked into the main Tauri
# binary (ipa-keyboard-daemon is a Rust dependency, not a sidecar). Bundle
# layout is just Contents/MacOS/ipa-keyboard plus Resources, with no
# Frameworks/ or sidecars — so a single codesign on the bundle is sufficient.
#
# Staging note: this repo lives under ~/Desktop. A macOS file provider
# (com.apple.fileprovider.fpfs#P) re-adds xattrs (com.apple.FinderInfo,
# com.apple.provenance) within ~1s on every file there, faster than codesign
# can run. codesign --strict then rejects the bundle with "resource fork,
# Finder information, or similar detritus not allowed". We work around it by
# staging the bundle + DMG under /tmp where the provider isn't active, doing
# all signing and notarization there, and only moving the final DMG back.
# =============================================================================
DMG_NAME="IPA_Keyboard_${VERSION}_universal.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

if [ "$SIGN_AND_NOTARIZE" = true ]; then
    ENTITLEMENTS="$REPO_ROOT/companion-app/src-tauri/Entitlements.plist"
    [ -f "$ENTITLEMENTS" ] || error "Entitlements file not found: $ENTITLEMENTS"

    STAGE_DIR="$(mktemp -d /tmp/ipa-keyboard-sign.XXXXXX)"
    trap 'rm -rf "$STAGE_DIR"' EXIT
    STAGE_APP="$STAGE_DIR/$(basename "$APP_PATH")"
    STAGE_DMG="$STAGE_DIR/$DMG_NAME"
    log "Staging bundle in $STAGE_DIR (xattrs are unstable on Desktop)"

    # ditto preserves bundle contents but lets us strip xattrs cleanly in /tmp.
    ditto "$APP_PATH" "$STAGE_APP"
    xattr -cr "$STAGE_APP"

    log "Signing app bundle (hardened runtime, timestamped)..."
    codesign --force \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$APPLE_SIGNING_IDENTITY" \
        --timestamp \
        "$STAGE_APP"

    log "Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$STAGE_APP" 2>&1 | sed 's/^/  /'

    log "Notarizing app bundle (this may take several minutes)..."
    bash "$REPO_ROOT/scripts/notarize-macos.sh" "$STAGE_APP"

    log "Creating DMG: $DMG_NAME (in stage)"
    hdiutil create \
        -volname "IPA Keyboard" \
        -srcfolder "$STAGE_APP" \
        -ov -format UDZO \
        "$STAGE_DMG"

    log "Signing DMG..."
    codesign --force \
        --sign "$APPLE_SIGNING_IDENTITY" \
        --timestamp \
        "$STAGE_DMG"

    log "Notarizing DMG (this may take several minutes)..."
    bash "$REPO_ROOT/scripts/notarize-macos.sh" "$STAGE_DMG"

    log "Moving signed DMG into place: $DMG_PATH"
    mv "$STAGE_DMG" "$DMG_PATH"
else
    warn "Skipping signing + notarization (--unsigned flag). Build will require Gatekeeper bypass."
    log "Creating DMG: $DMG_NAME"
    hdiutil create \
        -volname "IPA Keyboard" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

# =============================================================================
# Generate installation instructions
# =============================================================================
log "Generating installation instructions..."

if [ "$SIGN_AND_NOTARIZE" = true ]; then
    cat > "$RELEASE_DIR/INSTALL.txt" << 'INSTALL_EOF'
================================================================================
                        IPA KEYBOARD - INSTALLATION
================================================================================

1. Open the DMG (double-click).
2. Drag "IPA Keyboard.app" into your Applications folder.
3. Open IPA Keyboard from Applications.
4. When prompted, grant Accessibility permission:
     System Settings > Privacy & Security > Accessibility > enable IPA Keyboard
5. You may need to restart the app after granting permission.

================================================================================
USAGE
================================================================================

- Ctrl+Space    : Toggle IPA input mode ON/OFF
- Ctrl+Letter   : Type IPA symbol (cycle Ctrl+letter for variants)
- Menu bar icon : Shows current mode

================================================================================
COMPATIBILITY
================================================================================

- macOS 12.0 (Monterey) or later
- Intel and Apple Silicon (Universal Binary)

================================================================================
INSTALL_EOF
else
    cat > "$RELEASE_DIR/INSTALL.txt" << 'INSTALL_EOF'
================================================================================
            IPA KEYBOARD - INSTALLATION (UNSIGNED DEV BUILD)
================================================================================

This is an UNSIGNED development build. Production releases are signed and
notarized. To produce a signed build, run:

    bash scripts/build-release.sh

(without --unsigned, with the Apple credentials documented in
docs/PHASE-MAC-SIGNING.md set in the environment.)

To run this dev build:

1. Mount the DMG and drag "IPA Keyboard.app" to /Applications.
2. Run in Terminal:
       xattr -cr /Applications/IPA\ Keyboard.app
3. Double-click the app to open.
4. Grant Accessibility permission when prompted.

================================================================================
USAGE
================================================================================

- Ctrl+Space    : Toggle IPA input mode ON/OFF
- Ctrl+Letter   : Type IPA symbol (cycle Ctrl+letter for variants)

================================================================================
INSTALL_EOF

    cat > "$RELEASE_DIR/fix-gatekeeper.command" << 'SCRIPT_EOF'
#!/bin/bash
# Dev-only helper. Production builds are signed + notarized; this is unused.
echo "Removing quarantine attributes from IPA Keyboard..."
if [ -d "/Applications/IPA Keyboard.app" ]; then
    xattr -cr "/Applications/IPA Keyboard.app"
    echo "Done!"
else
    echo "IPA Keyboard not found in /Applications"
fi
echo ""
echo "Press any key to close..."
read -n 1
SCRIPT_EOF
    chmod +x "$RELEASE_DIR/fix-gatekeeper.command"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================================================="
log "BUILD COMPLETE"
echo "=============================================================================="
echo ""
echo "Output files in: $RELEASE_DIR"
echo ""
ls -lh "$RELEASE_DIR"
echo ""

if [ "$SIGN_AND_NOTARIZE" = true ]; then
    log "Signed + notarized. Distribute the DMG directly."
else
    warn "UNSIGNED BUILD. Users must run 'xattr -cr' to bypass Gatekeeper."
fi
echo ""
