#!/usr/bin/env bash
# generate-ipa-mapping.sh
# Reads shared-config/default-mappings.json and emits IPAMapping.swift.
# Also reads companion-app/src/data/ipa-symbols.json and ipa-names.ts
# and emits SymbolReferenceData.swift and LocalizedSymbolNames.swift.
# Run from repo root or any subdirectory — the script resolves paths itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_JSON="$REPO_ROOT/shared-config/default-mappings.json"
OUT_FILE="$REPO_ROOT/ios/IPACore/Sources/IPACore/IPAMapping.swift"

SYMBOLS_JSON="$REPO_ROOT/companion-app/src/data/ipa-symbols.json"
NAMES_TS="$REPO_ROOT/companion-app/src/data/ipa-names.ts"
SYMBOL_OUT="$REPO_ROOT/ios/IPACore/Sources/IPACore/SymbolReferenceData.swift"
NAMES_OUT="$REPO_ROOT/ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift"

if [[ ! -f "$SOURCE_JSON" ]]; then
    echo "ERROR: $SOURCE_JSON not found" >&2
    exit 1
fi

if [[ ! -f "$SYMBOLS_JSON" ]]; then
    echo "ERROR: $SYMBOLS_JSON not found" >&2
    exit 1
fi

if [[ ! -f "$NAMES_TS" ]]; then
    echo "ERROR: $NAMES_TS not found" >&2
    exit 1
fi

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

import Foundation

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

# -----------------------------------------------------------------------------
# SymbolReferenceData.swift — flat list of (symbol, example) for every variant
# in IPAMapping, in dottedKeys × variants order. Examples come from ipa-symbols.json.
# -----------------------------------------------------------------------------

SYMBOLS_HASH="$(shasum -a 256 "$SYMBOLS_JSON" | awk '{print $1}')"

# Build the reference rows using jq. Output format: each line is
# <swift-escaped-symbol>\t<swift-escaped-example>
# We iterate dottedKeys × variants from default-mappings.json and look up each
# variant's `example` in the flattened ipa-symbols.json. Missing lookups fail loudly.
REFERENCE_ROWS_TSV="$(jq -rn \
    --slurpfile mappings "$SOURCE_JSON" \
    --slurpfile symbols "$SYMBOLS_JSON" \
    '
    # Build a lookup: symbol -> example, from all leaf objects in symbols.
    ($symbols[0] | [.. | objects | select(has("symbol"))] | map({key: .symbol, value: .example}) | from_entries) as $lookup
    | ($mappings[0].mappings) as $m
    | ($m | keys_unsorted) as $keys
    | [ $keys[] as $k | $m[$k][] as $v |
        if ($lookup[$v] == null) then
            error("no example found for variant \($v) (key \($k)) in ipa-symbols.json")
        else
            [$v, $lookup[$v]]
        end
      ]
    | .[] | "\(.[0])\t\(.[1])"
    ' "$SOURCE_JSON")"

# Build Swift rows, escaping backslashes and double quotes in each field.
swift_escape() {
    # Escape backslashes first, then double quotes.
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

REFERENCE_ROWS_SWIFT=""
while IFS=$'\t' read -r sym ex; do
    [[ -z "$sym" ]] && continue
    sym_esc="$(swift_escape "$sym")"
    ex_esc="$(swift_escape "$ex")"
    REFERENCE_ROWS_SWIFT+="        SymbolRow(symbol: \"$sym_esc\", example: \"$ex_esc\"),"$'\n'
done <<< "$REFERENCE_ROWS_TSV"

# Strip trailing newline so heredoc formatting stays tidy
REFERENCE_ROWS_SWIFT="${REFERENCE_ROWS_SWIFT%$'\n'}"

cat > "$SYMBOL_OUT" << SWIFT
// SymbolReferenceData.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: ${SYMBOLS_HASH}

// swiftlint:disable all

import Foundation

public struct SymbolRow: Equatable, Hashable, Sendable {
    public let symbol: String
    public let example: String
    // Explicit public init — Swift's memberwise init is internal by default.
    public init(symbol: String, example: String) {
        self.symbol = symbol
        self.example = example
    }
}

public enum SymbolReferenceData {

    /// SHA256 of companion-app/src/data/ipa-symbols.json at codegen time.
    public static let sourceHash: String = "${SYMBOLS_HASH}"

    /// Rows in dottedKeys order, then variant order from default-mappings.json.
    public static let rows: [SymbolRow] = [
${REFERENCE_ROWS_SWIFT}
    ]
}
SWIFT

echo "Wrote $SYMBOL_OUT (sourceHash=${SYMBOLS_HASH})"

# -----------------------------------------------------------------------------
# LocalizedSymbolNames.swift — every (symbol, english name) pair from ipa-names.ts,
# in source order. Duplicate symbols with conflicting names fail the build.
# -----------------------------------------------------------------------------

NAMES_HASH="$(shasum -a 256 "$NAMES_TS" | awk '{print $1}')"

# Extract tab-separated (symbol, name) pairs in source order.
NAMES_TSV="$(grep -oE 'symbol: "[^"]+", name: "[^"]+"' "$NAMES_TS" \
    | sed -E 's/symbol: "([^"]+)", name: "([^"]+)"/\1\t\2/')"

# Sanity-check the extraction count against a lower bound derived from the
# source file itself: the number of object-literal entries (lines that begin
# with `{`). This count is independent of field order, so if someone
# reorders `name` before `symbol`, the extraction regex above silently
# yields fewer rows while the expected count stays the same — and we fail
# loudly instead of emitting a silently-truncated map.
EXPECTED_NAMES_COUNT="$(grep -cE '^\s*\{' "$NAMES_TS")"
EXTRACTED_NAMES_COUNT="$(printf '%s\n' "$NAMES_TSV" | grep -c $'\t' || true)"
if [[ "$EXTRACTED_NAMES_COUNT" -lt "$EXPECTED_NAMES_COUNT" ]]; then
    echo "ERROR: name extraction from $NAMES_TS produced $EXTRACTED_NAMES_COUNT rows, expected at least $EXPECTED_NAMES_COUNT." >&2
    echo "       Likely cause: field order changed in ipa-names.ts (name before symbol), a new escaping form was introduced," >&2
    echo "       or the regex in generate-ipa-mapping.sh no longer matches. Update the regex or normalize the source." >&2
    exit 1
fi

# Detect duplicates with conflicting names. Identical duplicates are also rejected
# so the source file stays canonical — we only accept each symbol once.
DUP_CHECK="$(printf '%s\n' "$NAMES_TSV" | awk -F'\t' 'NF>=2 { if (seen[$1]++) { print $1 "\t" $2 } }')"
if [[ -n "$DUP_CHECK" ]]; then
    echo "ERROR: duplicate symbol entries in $NAMES_TS:" >&2
    printf '%s\n' "$DUP_CHECK" >&2
    exit 1
fi

NAMES_ROWS_SWIFT=""
while IFS=$'\t' read -r sym name; do
    [[ -z "$sym" ]] && continue
    sym_esc="$(swift_escape "$sym")"
    name_esc="$(swift_escape "$name")"
    NAMES_ROWS_SWIFT+="        \"$sym_esc\": \"$name_esc\","$'\n'
done <<< "$NAMES_TSV"

NAMES_ROWS_SWIFT="${NAMES_ROWS_SWIFT%$'\n'}"

cat > "$NAMES_OUT" << SWIFT
// LocalizedSymbolNames.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: ${NAMES_HASH}

// swiftlint:disable all

import Foundation

public enum LocalizedSymbolNames {

    /// SHA256 of companion-app/src/data/ipa-names.ts at codegen time.
    public static let sourceHash: String = "${NAMES_HASH}"

    /// Maps IPA symbol string → English name. Includes the full library, not just mapped variants.
    public static let english: [String: String] = [
${NAMES_ROWS_SWIFT}
    ]
}
SWIFT

echo "Wrote $NAMES_OUT (sourceHash=${NAMES_HASH})"
