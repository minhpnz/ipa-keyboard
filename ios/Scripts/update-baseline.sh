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
