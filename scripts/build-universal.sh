#!/bin/bash
# Build universal (Intel + Apple Silicon) IPA Keyboard .app + DMG
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARIES_DIR="$REPO_ROOT/companion-app/src-tauri/binaries"
mkdir -p "$BINARIES_DIR"

echo "=== Building daemon for both architectures ==="
cargo build -p ipa-keyboard-daemon --release --target aarch64-apple-darwin --manifest-path "$REPO_ROOT/Cargo.toml"
cargo build -p ipa-keyboard-daemon --release --target x86_64-apple-darwin --manifest-path "$REPO_ROOT/Cargo.toml"

echo "=== Creating universal daemon binary ==="
lipo -create \
  "$REPO_ROOT/target/aarch64-apple-darwin/release/ipa-keyboard-daemon" \
  "$REPO_ROOT/target/x86_64-apple-darwin/release/ipa-keyboard-daemon" \
  -output "$BINARIES_DIR/ipa-keyboard-daemon-universal-apple-darwin"
chmod +x "$BINARIES_DIR/ipa-keyboard-daemon-universal-apple-darwin"

# Also provide per-arch copies for Tauri sidecar
cp "$REPO_ROOT/target/aarch64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-aarch64-apple-darwin"
cp "$REPO_ROOT/target/x86_64-apple-darwin/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-x86_64-apple-darwin"

echo "=== Building universal Tauri app ==="
cd "$REPO_ROOT/companion-app"
npm run tauri build -- --target universal-apple-darwin 2>&1 || true

APP="$REPO_ROOT/companion-app/src-tauri/target/universal-apple-darwin/release/bundle/macos/IPA Keyboard.app"
if [ ! -d "$APP" ]; then
  APP="$REPO_ROOT/companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app"
fi

echo "=== Creating DMG ==="
hdiutil create \
  -volname "IPA Keyboard" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  ~/Desktop/IPA-Keyboard-0.1.0-universal.dmg

echo "=== Done ==="
echo "DMG: ~/Desktop/IPA-Keyboard-0.1.0-universal.dmg"
