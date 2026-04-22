#!/bin/bash
# Post-build script: copies the IME .app into the companion app's Resources/
# Run after `npm run tauri build` to include the IME in the production bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IME_APP="$PROJECT_ROOT/ime-core/macos/build/IPAKeyboard.app"
COMPANION_APP="$PROJECT_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"

if [ ! -d "$IME_APP" ]; then
    echo "Error: IME not built. Run: cd ime-core/macos && bash build.sh"
    exit 1
fi

if [ ! -d "$COMPANION_APP" ]; then
    echo "Error: Companion app not built. Run: cd companion-app && npm run tauri build"
    exit 1
fi

DEST="$COMPANION_APP/Contents/Resources/IPAKeyboard.app"

echo "Bundling IME into companion app..."
rm -rf "$DEST"
cp -R "$IME_APP" "$DEST"
xattr -cr "$DEST"

echo "Done: $DEST"
echo ""
echo "The companion app will now auto-install the IME on first launch."
