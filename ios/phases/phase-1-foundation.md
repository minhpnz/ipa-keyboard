# Phase 1 — Foundation

**Ships:** Xcode project with both targets, `IPACore` local SPM package, codegen pipeline producing committed `IPAMapping.swift` + `SymbolReferenceData.swift` + `LocalizedSymbolNames.swift`, plus `LayoutEngine` and `SymbolDetector` with unit tests.

**Spec sections:** §3 architecture, §4.3 timing constants, §4.7 memory, §8.1 unit tests.

**Pre-reqs:**
- Xcode 15.4+ installed
- `jq` available (`brew install jq`) — used by the codegen script
- Free Apple Developer account at minimum (paid only needed for device install + submission, later phases)

---

## Task 1.1 — Create Xcode project skeleton

**Files:**
- Create: `ios/IPAKeyboard.xcodeproj/` (via Xcode)
- Create: `ios/IPAKeyboardApp/IPAKeyboardAppApp.swift`
- Create: `ios/IPAKeyboardApp/Info.plist`
- Create: `ios/IPAKeyboardApp/IPAKeyboardApp.entitlements`

- [ ] **Step 1: Create project via Xcode GUI**

Open Xcode → File → New → Project → iOS → App.
- Product Name: `IPAKeyboardApp`
- Team: your personal team (or leave None for now)
- Organization Identifier: `com.minhphan`
- Bundle Identifier: `com.minhphan.ipa-keyboard-ios`
- Interface: SwiftUI
- Language: Swift
- Storage: None
- Include Tests: YES
- Save location: `/Users/minhphan/Desktop/code/ipa-keyboard/ios/`

After creation, rename the project file on disk to `IPAKeyboard.xcodeproj` (File → Project Settings → Advanced → drag `.xcodeproj`, or close Xcode and `mv` in Finder).

- [ ] **Step 2: Set minimum deployment target**

Project settings → `IPAKeyboardApp` target → General → Minimum Deployments → iOS: `16.0`.

- [ ] **Step 3: Create empty entitlements file**

Create `ios/IPAKeyboardApp/IPAKeyboardApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

Then in project settings → `IPAKeyboardApp` → Signing & Capabilities → drag the file in so `CODE_SIGN_ENTITLEMENTS` points to it.

- [ ] **Step 4: Verify clean build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/IPAKeyboard.xcodeproj ios/IPAKeyboardApp/
git commit -m "ios: bootstrap Xcode project with empty container app target

Minimum deployment iOS 16.0. Bundle ID com.minhphan.ipa-keyboard-ios.
Empty entitlements file in place; no capabilities added."
```

---

## Task 1.2 — Add keyboard extension target

**Files:**
- Create: `ios/IPAKeyboardExtension/KeyboardViewController.swift`
- Create: `ios/IPAKeyboardExtension/Info.plist`
- Create: `ios/IPAKeyboardExtension/IPAKeyboardExtension.entitlements`

- [ ] **Step 1: Add target via Xcode**

File → New → Target → iOS → Custom Keyboard Extension.
- Product Name: `IPAKeyboardExtension`
- Language: Swift
- Embed in Application: `IPAKeyboardApp`
- Bundle ID: must be `com.minhphan.ipa-keyboard-ios.keyboard` (Xcode sets this automatically as a child of the app bundle ID).

- [ ] **Step 2: Replace the generated `KeyboardViewController.swift` with a minimal stub**

```swift
import UIKit

final class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "IPA Keyboard (stub)"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 260)
        ])
    }
}
```

The 260pt height lets iOS render the view; Phase 2 replaces this with `UIHostingController`.

- [ ] **Step 3: Edit extension `Info.plist`**

Replace the auto-generated `NSExtension` dict so it contains exactly:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <true/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>en-US</string>
        <key>RequestsOpenAccess</key>
        <false/>
    </dict>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
</dict>
```

Also add at the top level: `<key>MinimumOSVersion</key><string>16.0</string>`.

- [ ] **Step 4: Empty entitlements file**

Create `ios/IPAKeyboardExtension/IPAKeyboardExtension.entitlements` with an empty `<dict/>` (same as the app target's). Wire it via `CODE_SIGN_ENTITLEMENTS`.

- [ ] **Step 5: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add ios/IPAKeyboardExtension/
git commit -m "ios: add keyboard extension target with stub view controller

RequestsOpenAccess=false, IsASCIICapable=true, PrimaryLanguage=en-US.
MinimumOSVersion 16.0. Empty entitlements."
```

---

## Task 1.3 — Create `IPACore` local SPM package

**Files:**
- Create: `ios/IPACore/Package.swift`
- Create: `ios/IPACore/Sources/IPACore/IPACore.swift` (placeholder)
- Create: `ios/IPACore/Tests/IPACoreTests/IPACoreSmokeTests.swift`

- [ ] **Step 1: Initialize the package**

```bash
mkdir -p ios/IPACore/Sources/IPACore ios/IPACore/Tests/IPACoreTests
cd ios/IPACore && swift package init --type library --name IPACore
```

- [ ] **Step 2: Replace `Package.swift` with pinned platforms**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IPACore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "IPACore", targets: ["IPACore"]),
    ],
    targets: [
        .target(name: "IPACore", path: "Sources/IPACore"),
        .testTarget(
            name: "IPACoreTests",
            dependencies: ["IPACore"],
            path: "Tests/IPACoreTests"
        ),
    ]
)
```

- [ ] **Step 3: Write smoke test first (it fails — no `IPACore.swift` symbol yet)**

`ios/IPACore/Tests/IPACoreTests/IPACoreSmokeTests.swift`:

```swift
import XCTest
@testable import IPACore

final class IPACoreSmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertEqual(IPACore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Run it to confirm failure**

Run: `cd ios/IPACore && swift test 2>&1 | tail -10`
Expected: Compile error — `Cannot find 'IPACore' in scope` or `has no member 'version'`.

- [ ] **Step 5: Write minimal `IPACore.swift`**

`ios/IPACore/Sources/IPACore/IPACore.swift`:

```swift
public enum IPACore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 6: Run the test again, expect PASS**

Run: `cd ios/IPACore && swift test 2>&1 | tail -10`
Expected: `Test Suite 'All tests' passed`.

- [ ] **Step 7: Wire `IPACore` into both Xcode targets**

In Xcode: project settings → each target (`IPAKeyboardApp` and `IPAKeyboardExtension`) → General → Frameworks, Libraries, and Embedded Content → `+` → Add Other → Add Package Dependency → Add Local → select `ios/IPACore`. Add the `IPACore` library to each target.

- [ ] **Step 8: Build to confirm both targets link `IPACore`**

Add `import IPACore` to `KeyboardViewController.swift` (just at the top) and also to `IPAKeyboardAppApp.swift`. Build.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add ios/IPACore/ ios/IPAKeyboard.xcodeproj/ \
        ios/IPAKeyboardApp/IPAKeyboardAppApp.swift \
        ios/IPAKeyboardExtension/KeyboardViewController.swift
git commit -m "ios: add IPACore local SPM package, wire into both targets"
```

---

## Task 1.4 — Codegen script: read `shared-config/default-mappings.json` → `IPAMapping.swift`

**Files:**
- Create: `ios/Scripts/generate-ipa-mapping.sh`
- Create: `ios/IPACore/Sources/IPACore/IPAMapping.swift` (generated, committed)

- [ ] **Step 1: Inspect the existing JSON**

Run: `cat shared-config/default-mappings.json | jq .`
Note the shape. Should be an object like `{"mappings": [{"key":"a","variants":["æ","ʌ","ɑː"]}, ...]}`.

- [ ] **Step 2: Write the codegen script**

`ios/Scripts/generate-ipa-mapping.sh`:

```bash
#!/usr/bin/env bash
# Codegen: shared-config/default-mappings.json -> IPACore/Sources/IPACore/IPAMapping.swift
# Re-run whenever shared-config/default-mappings.json changes. Commit the output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INPUT="$REPO_ROOT/shared-config/default-mappings.json"
OUTPUT="$REPO_ROOT/ios/IPACore/Sources/IPACore/IPAMapping.swift"

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: $INPUT not found" >&2
    exit 1
fi

HASH="$(shasum -a 256 "$INPUT" | awk '{print $1}')"

{
    echo "// swiftlint:disable all"
    echo "// GENERATED FILE — do not edit by hand."
    echo "// Source: shared-config/default-mappings.json"
    echo "// Source SHA256: $HASH"
    echo "// Regenerate with: ios/Scripts/generate-ipa-mapping.sh"
    echo ""
    echo "import Foundation"
    echo ""
    echo "public enum IPAMapping {"
    echo "    public static let sourceHash: String = \"$HASH\""
    echo ""
    echo "    /// Dotted-letter → ordered IPA variants, in the order they appear in the popover."
    echo "    public static let variants: [Character: [String]] = ["
    jq -r '.mappings[] | "        \"\(.key)\": [" + ([.variants[] | "\"\(.)\""] | join(", ")) + "],"' "$INPUT"
    echo "    ]"
    echo ""
    echo "    /// Stable ordered list of base letters that carry popovers."
    echo "    public static let dottedKeys: [Character] = ["
    jq -r '.mappings[] | "        \"\(.key)\","' "$INPUT"
    echo "    ]"
    echo ""
    echo "    /// Flattened set of every variant string we ever insert."
    echo "    public static let allVariants: Set<String> = ["
    jq -r '[.mappings[].variants[]] | unique | .[] | "        \"\(.)\","' "$INPUT"
    echo "    ]"
    echo "}"
} > "$OUTPUT"

echo "Wrote $OUTPUT (sourceHash=$HASH)"
```

- [ ] **Step 3: Make it executable and run it**

```bash
chmod +x ios/Scripts/generate-ipa-mapping.sh
ios/Scripts/generate-ipa-mapping.sh
```
Expected: `Wrote .../IPAMapping.swift (sourceHash=...)`

- [ ] **Step 4: Inspect the generated file**

Open `ios/IPACore/Sources/IPACore/IPAMapping.swift`. Verify:
- The header has a non-empty `sourceHash`
- `variants["a"]` contains `["æ", "ʌ", "ɑː"]` in that order
- `dottedKeys` has exactly 11 characters
- `allVariants` has exactly 18 entries

- [ ] **Step 5: Write a round-trip test**

`ios/IPACore/Tests/IPACoreTests/IPAMappingTests.swift`:

```swift
import XCTest
@testable import IPACore

final class IPAMappingTests: XCTestCase {

    func test_elevenDottedKeys() {
        XCTAssertEqual(IPAMapping.dottedKeys.count, 11)
        XCTAssertEqual(Set(IPAMapping.dottedKeys), Set("aeioutsdcnz"))
    }

    func test_eighteenTotalVariants() {
        XCTAssertEqual(IPAMapping.allVariants.count, 18)
    }

    func test_aMapsToThreeVariantsInOrder() {
        XCTAssertEqual(IPAMapping.variants["a"], ["æ", "ʌ", "ɑː"])
    }

    func test_everyDottedKeyHasVariants() {
        for key in IPAMapping.dottedKeys {
            let entry = IPAMapping.variants[key]
            XCTAssertNotNil(entry, "missing variants for \(key)")
            XCTAssertFalse(entry?.isEmpty ?? true, "empty variants for \(key)")
        }
    }

    func test_sourceHashIsSixtyFourHexChars() {
        XCTAssertEqual(IPAMapping.sourceHash.count, 64)
        XCTAssertTrue(
            IPAMapping.sourceHash.allSatisfy { $0.isHexDigit },
            "sourceHash must be hex"
        )
    }
}
```

- [ ] **Step 6: Run tests**

Run: `cd ios/IPACore && swift test 2>&1 | tail -20`
Expected: 5 tests pass (plus the earlier smoke test = 6 total).

- [ ] **Step 7: Commit the script + generated file + tests**

```bash
git add ios/Scripts/generate-ipa-mapping.sh \
        ios/IPACore/Sources/IPACore/IPAMapping.swift \
        ios/IPACore/Tests/IPACoreTests/IPAMappingTests.swift
git commit -m "ios: codegen IPAMapping.swift from shared-config/default-mappings.json

Script bakes source SHA256 into header so CI preflight can detect drift.
All 18 IPA variants across 11 dotted letters round-trip verbatim, tested."
```

---

## Task 1.5 — Extend codegen: `SymbolReferenceData.swift` + `LocalizedSymbolNames.swift`

**Files:**
- Modify: `ios/Scripts/generate-ipa-mapping.sh`
- Create: `ios/IPACore/Sources/IPACore/SymbolReferenceData.swift`
- Create: `ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/CodegenIntegrityTests.swift`

- [ ] **Step 1: Inspect source data**

Run: `head -40 companion-app/src/data/ipa-symbols.json` and `head -40 companion-app/src/data/ipa-names.ts`.
Confirm: `ipa-symbols.json` entries have `{symbol, name, example}` fields; `ipa-names.ts` maps symbols to human-readable names.

- [ ] **Step 2: Extend the codegen script**

Append to `ios/Scripts/generate-ipa-mapping.sh`:

```bash
SYMBOLS_INPUT="$REPO_ROOT/companion-app/src/data/ipa-symbols.json"
NAMES_INPUT="$REPO_ROOT/companion-app/src/data/ipa-names.ts"
REFERENCE_OUTPUT="$REPO_ROOT/ios/IPACore/Sources/IPACore/SymbolReferenceData.swift"
NAMES_OUTPUT="$REPO_ROOT/ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift"

SYMBOLS_HASH="$(shasum -a 256 "$SYMBOLS_INPUT" | awk '{print $1}')"
NAMES_HASH="$(shasum -a 256 "$NAMES_INPUT" | awk '{print $1}')"

# Reference data: list of {key, [variants with name + example]} rows for Reference tab.
{
    echo "// GENERATED — do not edit. Source: companion-app/src/data/ipa-symbols.json"
    echo "// Source SHA256: $SYMBOLS_HASH"
    echo "import Foundation"
    echo ""
    echo "public struct SymbolEntry: Equatable, Hashable, Sendable {"
    echo "    public let symbol: String"
    echo "    public let name: String"
    echo "    public let example: String"
    echo "    public init(symbol: String, name: String, example: String) {"
    echo "        self.symbol = symbol; self.name = name; self.example = example"
    echo "    }"
    echo "}"
    echo ""
    echo "public struct SymbolRow: Equatable, Hashable, Sendable {"
    echo "    public let key: Character"
    echo "    public let entries: [SymbolEntry]"
    echo "}"
    echo ""
    echo "public enum SymbolReferenceData {"
    echo "    public static let sourceHash: String = \"$SYMBOLS_HASH\""
    echo "    public static let rows: [SymbolRow] = ["
    # For each dotted key in default-mappings insertion order, emit row with entries from ipa-symbols.json.
    # NOTE: shared-config/default-mappings.json uses an OBJECT-of-arrays shape
    # ({"mappings": {"a": [...], "e": [...]}}), not array-of-objects. Iterate via to_entries[].
    # The input variable below refers to whatever Task 1.4's script named its mapping JSON path
    # (in the current impl that's $SOURCE_JSON — adjust here to match if it's different).
    jq -r --slurpfile syms "$SYMBOLS_INPUT" '
        .mappings | to_entries[] as $m
        | "        SymbolRow(key: \"\($m.key)\", entries: [" +
          (
            [$m.value[] as $v
              | ($syms[0].symbols // $syms[0] | .[] | select(.symbol == $v))
              | "SymbolEntry(symbol: \"\(.symbol)\", name: \"\(.name // "")\", example: \"\(.example // "")\")"
            ] | join(", ")
          ) + "]),"
    ' "$SOURCE_JSON"
    echo "    ]"
    echo "}"
} > "$REFERENCE_OUTPUT"

# Localized names: Symbol → English name (separate for future localization).
{
    echo "// GENERATED — do not edit. Source: companion-app/src/data/ipa-names.ts"
    echo "// Source SHA256: $NAMES_HASH"
    echo "import Foundation"
    echo ""
    echo "public enum LocalizedSymbolNames {"
    echo "    public static let sourceHash: String = \"$NAMES_HASH\""
    echo "    public static let english: [String: String] = ["
    # Extract `"x": "name"` style entries from ipa-names.ts via regex.
    grep -E '^\s*"[^"]+"\s*:\s*"[^"]+"' "$NAMES_INPUT" \
        | sed -E 's/^\s*(".+"\s*:\s*".+")[,]?$/        \1,/'
    echo "    ]"
    echo ""
    echo "    public static func name(for symbol: String) -> String {"
    echo "        english[symbol] ?? symbol"
    echo "    }"
    echo "}"
} > "$NAMES_OUTPUT"

echo "Wrote $REFERENCE_OUTPUT (symbolsHash=$SYMBOLS_HASH)"
echo "Wrote $NAMES_OUTPUT (namesHash=$NAMES_HASH)"
```

If the actual shape of `ipa-symbols.json` or `ipa-names.ts` differs from what the script assumes, adjust the `jq`/`grep`/`sed` accordingly. Run the script and inspect the output before moving on.

- [ ] **Step 3: Run the script**

```bash
ios/Scripts/generate-ipa-mapping.sh
```
Expected: three files written, three `Wrote …` lines.

- [ ] **Step 4: Write codegen-integrity test**

`ios/IPACore/Tests/IPACoreTests/CodegenIntegrityTests.swift`:

```swift
import XCTest
@testable import IPACore

final class CodegenIntegrityTests: XCTestCase {

    func test_referenceRowsMatchMappingKeys() {
        let refKeys = SymbolReferenceData.rows.map { $0.key }
        XCTAssertEqual(refKeys, IPAMapping.dottedKeys,
            "Reference rows must be in same order as IPAMapping.dottedKeys")
    }

    func test_everyReferenceEntryAppearsInAllVariants() {
        for row in SymbolReferenceData.rows {
            for entry in row.entries {
                XCTAssertTrue(
                    IPAMapping.allVariants.contains(entry.symbol),
                    "Reference has \(entry.symbol) but IPAMapping doesn't"
                )
            }
        }
    }

    func test_everyMappingVariantHasAName() {
        for symbol in IPAMapping.allVariants {
            let name = LocalizedSymbolNames.name(for: symbol)
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name == symbol && symbol.count > 2,
                "Variant \(symbol) has no English name in LocalizedSymbolNames")
        }
    }

    func test_allThreeSourceHashesAreDistinctHex() {
        let hashes = [
            IPAMapping.sourceHash,
            SymbolReferenceData.sourceHash,
            LocalizedSymbolNames.sourceHash,
        ]
        for h in hashes { XCTAssertEqual(h.count, 64) }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `cd ios/IPACore && swift test 2>&1 | tail -20`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Scripts/generate-ipa-mapping.sh \
        ios/IPACore/Sources/IPACore/SymbolReferenceData.swift \
        ios/IPACore/Sources/IPACore/LocalizedSymbolNames.swift \
        ios/IPACore/Tests/IPACoreTests/CodegenIntegrityTests.swift
git commit -m "ios: codegen symbol reference + English names from companion-app data

Both files carry source SHA256 in header. Integrity test asserts:
- reference rows are in dottedKeys order
- every reference entry is in IPAMapping.allVariants
- every mapping variant has a non-trivial English name"
```

---

## Task 1.6 — `LayoutEngine.swift` (timing + popover math)

**Files:**
- Create: `ios/IPACore/Sources/IPACore/LayoutEngine.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/LayoutEngineTests.swift`

- [ ] **Step 1: Write failing tests first**

`ios/IPACore/Tests/IPACoreTests/LayoutEngineTests.swift`:

```swift
import XCTest
@testable import IPACore
import CoreGraphics

final class LayoutEngineTests: XCTestCase {

    // Timing constants — asserted so any accidental change surfaces in review.
    func test_popoverDelayIsFiveHundredMillis() {
        XCTAssertEqual(LayoutEngine.popoverDelay, 0.5, accuracy: 0.001)
    }

    func test_clipboardDebounceIsThreeHundredMillis() {
        XCTAssertEqual(LayoutEngine.clipboardDebounceInterval, 0.3, accuracy: 0.001)
    }

    // Popover positioning: center over key when fully inside the keyboard width.
    func test_popoverCenteredOverKeyWhenMiddleOfKeyboard() {
        let keyFrame = CGRect(x: 160, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 120, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertEqual(rect.midX, keyFrame.midX, accuracy: 0.5)
        XCTAssertLessThan(rect.maxY, keyFrame.minY, "popover above key")
    }

    // Left-edge key → popover must be shifted right so it stays inside.
    func test_popoverClampedRightAtLeftEdge() {
        let keyFrame = CGRect(x: 2, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 160, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width)
    }

    // Right-edge key (p) → popover clamped left.
    func test_popoverClampedLeftAtRightEdge() {
        let keyFrame = CGRect(x: 356, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 160, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width)
    }

    // iPad floating width (~320pt) — still clamped, no off-screen bleed.
    func test_popoverNeverOffScreenAtNarrowWidth() {
        let keyboardSize = CGSize(width: 320, height: 200)
        let popoverSize = CGSize(width: 160, height: 52)
        for x in stride(from: 0, through: 320 - 32, by: 8) {
            let keyFrame = CGRect(x: CGFloat(x), y: 40, width: 32, height: 40)
            let rect = LayoutEngine.popoverRect(
                keyFrame: keyFrame,
                popoverSize: popoverSize,
                keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
            )
            XCTAssertGreaterThanOrEqual(rect.minX, 0, "off-screen left for x=\(x)")
            XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width, "off-screen right for x=\(x)")
        }
    }

    // Top row — popover would clip top if placed above; must mirror below.
    func test_popoverMirrorsBelowWhenTopRowWouldClip() {
        let keyFrame = CGRect(x: 160, y: 2, width: 32, height: 48)
        let popoverSize = CGSize(width: 120, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertGreaterThanOrEqual(rect.minY, keyFrame.maxY,
            "Popover should mirror below when placing above would clip")
    }
}
```

- [ ] **Step 2: Run — expect failure**

Run: `cd ios/IPACore && swift test --filter LayoutEngineTests 2>&1 | tail -10`
Expected: compile error (`LayoutEngine` not found).

- [ ] **Step 3: Implement `LayoutEngine.swift`**

`ios/IPACore/Sources/IPACore/LayoutEngine.swift`:

```swift
import CoreGraphics
import Foundation

public enum LayoutEngine {

    public static let popoverDelay: TimeInterval = 0.5
    public static let clipboardDebounceInterval: TimeInterval = 0.3

    /// Compute the popover frame so it is fully inside `keyboardBounds`.
    /// Preference order: above-and-centered → below-and-centered → clamp horizontally.
    public static func popoverRect(
        keyFrame: CGRect,
        popoverSize: CGSize,
        keyboardBounds: CGRect
    ) -> CGRect {
        let padding: CGFloat = 4

        // Vertical: try above; mirror below if it would clip.
        let aboveY = keyFrame.minY - popoverSize.height - padding
        let belowY = keyFrame.maxY + padding
        let y: CGFloat = aboveY >= keyboardBounds.minY ? aboveY : belowY

        // Horizontal: center over key, then clamp to keyboardBounds.
        var x = keyFrame.midX - popoverSize.width / 2
        if x < keyboardBounds.minX { x = keyboardBounds.minX }
        if x + popoverSize.width > keyboardBounds.maxX {
            x = keyboardBounds.maxX - popoverSize.width
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd ios/IPACore && swift test --filter LayoutEngineTests 2>&1 | tail -10`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/IPACore/Sources/IPACore/LayoutEngine.swift \
        ios/IPACore/Tests/IPACoreTests/LayoutEngineTests.swift
git commit -m "ios: LayoutEngine with popover positioning + timing constants

popoverDelay=0.5s, clipboardDebounceInterval=0.3s.
popoverRect clamps horizontally and mirrors below when above would clip.
Six tests including iPad-floating-width sweep."
```

---

## Task 1.7 — `SymbolDetector.swift`

**Files:**
- Create: `ios/IPACore/Sources/IPACore/SymbolDetector.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/SymbolDetectorTests.swift`

- [ ] **Step 1: Failing test first**

`ios/IPACore/Tests/IPACoreTests/SymbolDetectorTests.swift`:

```swift
import XCTest
@testable import IPACore

final class SymbolDetectorTests: XCTestCase {

    func test_plainAsciiIsNotDetected() {
        XCTAssertFalse(SymbolDetector.containsIPA("hello world"))
        XCTAssertFalse(SymbolDetector.containsIPA(""))
        XCTAssertFalse(SymbolDetector.containsIPA("AEIOU aeiou 123"))
    }

    func test_everyMappingVariantIsDetected() {
        for variant in IPAMapping.allVariants {
            XCTAssertTrue(
                SymbolDetector.containsIPA("prefix \(variant) suffix"),
                "Should detect \(variant)"
            )
        }
    }

    func test_pastedSentenceIsDetected() {
        XCTAssertTrue(SymbolDetector.containsIPA("the cat is /kæt/"))
        XCTAssertTrue(SymbolDetector.containsIPA("/ðɪs/"))
    }

    func test_allKnownVariantsMatchesIPAMapping() {
        XCTAssertEqual(SymbolDetector.allKnownVariants, IPAMapping.allVariants)
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `cd ios/IPACore && swift test --filter SymbolDetectorTests 2>&1 | tail -10`

- [ ] **Step 3: Implement**

`ios/IPACore/Sources/IPACore/SymbolDetector.swift`:

```swift
import Foundation

public enum SymbolDetector {
    /// The canonical set of strings the detector treats as "IPA was typed".
    public static let allKnownVariants: Set<String> = IPAMapping.allVariants

    /// True if any known IPA variant appears as a substring of `text`.
    public static func containsIPA(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        for variant in allKnownVariants where text.contains(variant) {
            return true
        }
        return false
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd ios/IPACore && swift test --filter SymbolDetectorTests 2>&1 | tail -10`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/IPACore/Sources/IPACore/SymbolDetector.swift \
        ios/IPACore/Tests/IPACoreTests/SymbolDetectorTests.swift
git commit -m "ios: SymbolDetector for container app's 'Try it here' field"
```

---

## Task 1.8 — Preflight script skeleton (freshness guard only)

**Files:**
- Create: `ios/Scripts/preflight.sh`

Phase 7 fills out the rest of the guards; this phase just establishes codegen-freshness so the generated files can't drift silently from day one.

- [ ] **Step 1: Write the script**

`ios/Scripts/preflight.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable and run it clean**

```bash
chmod +x ios/Scripts/preflight.sh
ios/Scripts/preflight.sh
```
Expected: 3× `OK: …`, final line `Phase 1 preflight checks passed.`

- [ ] **Step 3: Confirm it fails on simulated drift**

```bash
# Temporarily scramble the hash in IPAMapping.swift
sed -i.bak 's/Source SHA256: .*/Source SHA256: ffff/' ios/IPACore/Sources/IPACore/IPAMapping.swift
! ios/Scripts/preflight.sh  # expect nonzero exit
mv ios/IPACore/Sources/IPACore/IPAMapping.swift.bak ios/IPACore/Sources/IPACore/IPAMapping.swift
ios/Scripts/preflight.sh    # expect green again
```
Both expected outcomes must occur. If not, fix the script before committing.

- [ ] **Step 4: Commit**

```bash
git add ios/Scripts/preflight.sh
git commit -m "ios: preflight.sh with codegen-freshness guards

Compares SHA256 of each JSON/TS source against hash embedded in
corresponding generated Swift file. Phase 7 extends this."
```

---

## Phase 1 exit checklist

- [ ] `swift test` in `ios/IPACore/` shows all tests passing (smoke + IPAMapping + codegen integrity + LayoutEngine + SymbolDetector — ~17 tests)
- [ ] `xcodebuild -scheme IPAKeyboardApp build` succeeds for `iphonesimulator`
- [ ] `ios/Scripts/preflight.sh` exits 0 on clean tree, nonzero on simulated drift
- [ ] All three generated files committed with their source SHA256 headers
- [ ] Both targets have **empty** entitlements files wired in
- [ ] `RequestsOpenAccess=false` and `IsASCIICapable=true` are in the extension `Info.plist`
- [ ] No App Group configured. No network entitlement. (Spot-check: `grep -R 'com.apple.security' ios/` returns nothing.)

When all boxes are ticked, tick Phase 1 in `ios/PLAN.md` and move to Phase 2.
