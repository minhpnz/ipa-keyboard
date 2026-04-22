#!/bin/bash
# Build the IPA keyboard daemon and place it where Tauri expects sidecar binaries.
# Tauri requires: binaries/<name>-<target-triple>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARIES_DIR="$REPO_ROOT/companion-app/src-tauri/binaries"
mkdir -p "$BINARIES_DIR"

# Detect current target triple
TARGET_TRIPLE=$(rustc -vV | grep 'host:' | awk '{print $2}')

echo "[build-daemon] Building ipa-keyboard-daemon for $TARGET_TRIPLE..."
cargo build -p ipa-keyboard-daemon --release --manifest-path "$REPO_ROOT/Cargo.toml"

# Copy with Tauri sidecar naming convention
cp "$REPO_ROOT/target/release/ipa-keyboard-daemon" \
   "$BINARIES_DIR/ipa-keyboard-daemon-$TARGET_TRIPLE"
chmod +x "$BINARIES_DIR/ipa-keyboard-daemon-$TARGET_TRIPLE"

echo "[build-daemon] Done: $BINARIES_DIR/ipa-keyboard-daemon-$TARGET_TRIPLE"
