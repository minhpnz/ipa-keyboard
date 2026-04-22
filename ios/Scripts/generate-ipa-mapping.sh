#!/usr/bin/env bash
# generate-ipa-mapping.sh
# Reads shared-config/default-mappings.json and emits IPAMapping.swift.
# Run from repo root or any subdirectory — the script resolves paths itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_JSON="$REPO_ROOT/shared-config/default-mappings.json"
OUT_FILE="$REPO_ROOT/ios/IPACore/Sources/IPACore/IPAMapping.swift"

# Compute SHA256 of the source JSON (macOS shasum)
SOURCE_HASH="$(shasum -a 256 "$SOURCE_JSON" | awk '{print $1}')"

# Build variants dictionary entries (key insertion order via keys_unsorted)
VARIANTS_ROWS="$(jq -r '.mappings | to_entries[] | "        \"\(.key)\": [" + ([.value[] | "\"\(.)\""] | join(", ")) + "],"' "$SOURCE_JSON")"

# Build dottedKeys array (JSON insertion order, not sorted)
DOTTED_KEYS="$(jq -r '.mappings | keys_unsorted[] | "        \"\(.)\"," ' "$SOURCE_JSON")"

# Build allVariants set (unique, flat)
ALL_VARIANTS="$(jq -r '[.mappings | to_entries[].value[]] | unique | .[] | "        \"\(.)\"," ' "$SOURCE_JSON")"

cat > "$OUT_FILE" << SWIFT
// IPAMapping.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: ${SOURCE_HASH}

// swiftlint:disable all

public enum IPAMapping {

    /// SHA256 of shared-config/default-mappings.json at codegen time.
    public static let sourceHash: String = "${SOURCE_HASH}"

    /// Maps each dotted key to its ordered IPA variants.
    public static let variants: [Character: [String]] = [
${VARIANTS_ROWS}
    ]

    /// Dotted-key characters in JSON insertion order.
    public static let dottedKeys: [Character] = [
${DOTTED_KEYS}
    ]

    /// All unique IPA variant strings across every key.
    public static let allVariants: Set<String> = [
${ALL_VARIANTS}
    ]
}
SWIFT

echo "Wrote $OUT_FILE (sourceHash=${SOURCE_HASH})"
