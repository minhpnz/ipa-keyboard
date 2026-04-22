#!/bin/bash
# =============================================================================
# IPA Keyboard - Release Build Script
# Builds universal macOS app and packages for distribution
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.1.0"
RELEASE_DIR="$REPO_ROOT/package-release"
BINARIES_DIR="$REPO_ROOT/companion-app/src-tauri/binaries"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# Pre-flight checks
# =============================================================================
log "Checking dependencies..."

command -v cargo >/dev/null 2>&1 || error "cargo not found. Install Rust first."
command -v npm >/dev/null 2>&1 || error "npm not found. Install Node.js first."
command -v lipo >/dev/null 2>&1 || error "lipo not found. Xcode CLI tools required."
command -v hdiutil >/dev/null 2>&1 || error "hdiutil not found. macOS required."

# Check for both targets
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

# Clean old release files
rm -f "$RELEASE_DIR"/*.dmg
rm -f "$RELEASE_DIR"/README*.txt
rm -f "$RELEASE_DIR"/INSTALL*.txt

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

# Copy per-arch binaries for Tauri sidecar
cp "$REPO_ROOT/target/aarch64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-aarch64-apple-darwin"
cp "$REPO_ROOT/target/x86_64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-x86_64-apple-darwin"

# =============================================================================
# Build Tauri app (universal)
# =============================================================================
log "Installing frontend dependencies..."
cd "$REPO_ROOT/companion-app"
npm install

log "Building universal Tauri app..."
npm run tauri build -- --target universal-apple-darwin 2>&1 || {
    warn "Universal build had warnings, checking output..."
}

# Find the built app
APP_PATH=""
if [ -d "$REPO_ROOT/companion-app/src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app" ]; then
    APP_PATH="$REPO_ROOT/companion-app/src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app"
elif [ -d "$REPO_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app" ]; then
    APP_PATH="$REPO_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"
else
    error "Could not find built .app bundle"
fi

log "Found app at: $APP_PATH"

# Verify it's universal
ARCH_INFO=$(file "$APP_PATH/Contents/MacOS/ipa-keyboard" 2>/dev/null || echo "unknown")
if echo "$ARCH_INFO" | grep -q "universal"; then
    log "Verified: Universal binary (Intel + Apple Silicon)"
else
    warn "Binary may not be universal: $ARCH_INFO"
fi

# =============================================================================
# Create DMG
# =============================================================================
DMG_NAME="IPA_Keyboard_${VERSION}_universal.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

log "Creating DMG: $DMG_NAME"
hdiutil create \
    -volname "IPA Keyboard" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# =============================================================================
# Generate installation instructions
# =============================================================================
log "Generating installation instructions..."

cat > "$RELEASE_DIR/INSTALL.txt" << 'INSTALL_EOF'
================================================================================
                        IPA KEYBOARD - INSTALLATION GUIDE
================================================================================

IMPORTANT: This app is not signed with an Apple Developer certificate.
           You need to follow these steps to run it.

================================================================================
METHOD 1: RECOMMENDED (Terminal - One Time)
================================================================================

1. Download and mount the DMG
2. Drag "IPA Keyboard.app" to your Applications folder
3. Open Terminal (Applications > Utilities > Terminal)
4. Run this command:

   xattr -cr /Applications/IPA\ Keyboard.app

5. Now double-click the app to open it normally

================================================================================
METHOD 2: Right-Click Open
================================================================================

1. Download and mount the DMG
2. Drag "IPA Keyboard.app" to your Applications folder
3. In Finder, RIGHT-CLICK (or Control-click) on "IPA Keyboard.app"
4. Select "Open" from the context menu
5. Click "Open" in the dialog that appears

   Note: This method may not work on macOS 15+ (Sequoia/Tahoe)

================================================================================
METHOD 3: System Settings
================================================================================

1. Try to open the app normally (it will be blocked)
2. Go to: System Settings > Privacy & Security
3. Scroll down to find "IPA Keyboard was blocked..."
4. Click "Open Anyway"
5. Enter your password if prompted

================================================================================
GRANTING ACCESSIBILITY PERMISSION
================================================================================

After opening the app, macOS will ask for Accessibility permission.
This is required for the keyboard to work system-wide.

1. Click "Open System Settings" when prompted
2. In Privacy & Security > Accessibility, enable "IPA Keyboard"
3. You may need to restart the app after granting permission

================================================================================
USAGE
================================================================================

- Ctrl+Space    : Toggle IPA input mode ON/OFF
- Ctrl+Letter   : Type IPA symbol (e.g., Ctrl+A for ɑ, cycle for variants)
- Menu bar icon : Shows current mode (click for options)

================================================================================
COMPATIBILITY
================================================================================

- macOS 12.0 (Monterey) or later
- Intel Mac: Native support
- Apple Silicon (M1/M2/M3/M4): Native support (Universal Binary)

================================================================================
TROUBLESHOOTING
================================================================================

"App is damaged and can't be opened"
  -> Run: xattr -cr /Applications/IPA\ Keyboard.app

"IPA Keyboard wants to use Accessibility"
  -> Grant permission in System Settings > Privacy & Security > Accessibility

App opens but keyboard doesn't work
  -> Check Accessibility permission is granted
  -> Try restarting the app
  -> On macOS 15+: You may need to restart your Mac after granting permission

================================================================================
INSTALL_EOF

# =============================================================================
# Generate bypass script for convenience
# =============================================================================
cat > "$RELEASE_DIR/fix-gatekeeper.command" << 'SCRIPT_EOF'
#!/bin/bash
# Double-click this file to fix Gatekeeper issues with IPA Keyboard

echo "Removing quarantine attributes from IPA Keyboard..."

if [ -d "/Applications/IPA Keyboard.app" ]; then
    xattr -cr "/Applications/IPA Keyboard.app"
    echo "Done! You can now open IPA Keyboard from Applications."
else
    echo "IPA Keyboard not found in /Applications"
    echo "Please drag the app to Applications folder first."
fi

echo ""
echo "Press any key to close..."
read -n 1
SCRIPT_EOF

chmod +x "$RELEASE_DIR/fix-gatekeeper.command"

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
echo "Files created:"
echo "  - $DMG_NAME              (distribute this)"
echo "  - INSTALL.txt            (user instructions)"
echo "  - fix-gatekeeper.command (users can double-click to fix permissions)"
echo ""
warn "NOTE: App is NOT signed. Users must bypass Gatekeeper (see INSTALL.txt)"
echo ""
