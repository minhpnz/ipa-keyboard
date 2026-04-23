#!/usr/bin/env bash
# iOS preflight — fails CI on policy violations.
# Phase 1 implements only codegen freshness; Phase 7 adds the rest.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail() { echo "PREFLIGHT FAIL: $1" >&2; exit 1; }

check_hash_in_file() {
    local source_file="$1"
    local generated_file="$2"
    local expected
    expected="$(shasum -a 256 "$source_file" | awk '{print $1}')"
    if ! grep -q "$expected" "$generated_file"; then
        fail "$generated_file is stale vs $source_file (hash $expected not found in header). Run ios/Scripts/generate-ipa-mapping.sh and commit."
    fi
    echo "OK: $generated_file fresh against $source_file"
}

check_hash_in_file "shared-config/default-mappings.json"        "ios/IPACore/Sources/IPACore/IPAMapping.swift"
check_hash_in_file "companion-app/src/data/ipa-symbols.json"    "ios/IPACore/Sources/IPACore/SymbolReferenceData.swift"
check_hash_in_file "companion-app/src/data/ipa-names.ts"        "ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift"

echo "Phase 1 preflight checks passed. (Phase 7 adds entitlements / forbidden-APIs / size-delta guards.)"
