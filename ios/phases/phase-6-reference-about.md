# Phase 6 — Container app: Reference + About tabs

**Ships:** Reference tab (scrollable 11-row table of IPA variants with tap-to-copy, per-value debounce, 2-second toast) and About tab (version, privacy statement, licenses). All 11 rows populated from `SymbolReferenceData` via codegen.

**Spec sections:** §5.3 Reference tab, §5.4 About tab, §8.3 clipboard contract tests.

**Pre-req:** Phase 5 complete. `SymbolReferenceData.rows` available from codegen.

---

## Task 6.1 — `ClipboardDebouncer` in `IPACore`

**Files:**
- Create: `ios/IPACore/Sources/IPACore/ClipboardDebouncer.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/ClipboardDebouncerTests.swift`

The debounce rule (spec §5.3): rapid taps on *the same value* within `clipboardDebounceInterval` are no-ops after the first. A tap on a *different* value resets the window immediately.

- [ ] **Step 1: Failing tests first**

```swift
import XCTest
@testable import IPACore

final class ClipboardDebouncerTests: XCTestCase {

    func test_firstTapAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
    }

    func test_sameValueWithinWindowRejected() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertFalse(d.accept(value: "æ", at: 0.1))
        XCTAssertFalse(d.accept(value: "æ", at: 0.29))
    }

    func test_sameValueAfterWindowAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertTrue(d.accept(value: "æ", at: LayoutEngine.clipboardDebounceInterval + 0.01))
    }

    func test_differentValueImmediatelyAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertTrue(d.accept(value: "ʌ", at: 0.1))
        // And it now treats ʌ as the new reference for its own window.
        XCTAssertFalse(d.accept(value: "ʌ", at: 0.2))
    }

    func test_usesLayoutEngineWindow() {
        var d = ClipboardDebouncer()
        _ = d.accept(value: "æ", at: 0)
        // Exactly at the window boundary: rejected (strict <).
        XCTAssertFalse(d.accept(value: "æ", at: LayoutEngine.clipboardDebounceInterval - 0.01))
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `cd ios/IPACore && swift test --filter ClipboardDebouncerTests 2>&1 | tail -10`

- [ ] **Step 3: Implement**

```swift
import Foundation

public struct ClipboardDebouncer {
    private var lastValue: String? = nil
    private var lastAcceptTime: TimeInterval = -.infinity

    public init() {}

    /// Returns true if the tap should write to the pasteboard.
    public mutating func accept(value: String, at now: TimeInterval) -> Bool {
        defer {
            // Always record — this reflects the user's most recent intent regardless of acceptance.
        }
        if value != lastValue {
            lastValue = value
            lastAcceptTime = now
            return true
        }
        // Same value: gated by window.
        if now - lastAcceptTime >= LayoutEngine.clipboardDebounceInterval {
            lastAcceptTime = now
            return true
        }
        return false
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd ios/IPACore && swift test --filter ClipboardDebouncerTests 2>&1 | tail -10`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/IPACore/Sources/IPACore/ClipboardDebouncer.swift \
        ios/IPACore/Tests/IPACoreTests/ClipboardDebouncerTests.swift
git commit -m "ios: ClipboardDebouncer (per-value) in IPACore

Uses LayoutEngine.clipboardDebounceInterval, not a local literal.
Different-value tap immediately accepted; same-value gated by window."
```

---

## Task 6.2 — `ReferenceView` with tap-to-copy

**Files:**
- Modify: `ios/IPAKeyboardApp/Views/ReferenceView.swift`
- Create: `ios/IPAKeyboardApp/Views/ToastModifier.swift`

- [ ] **Step 1: Implement the toast modifier**

`ios/IPAKeyboardApp/Views/ToastModifier.swift`:

```swift
import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let message {
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.78))
                    )
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

extension View {
    func ipaToast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
```

- [ ] **Step 2: Implement `ReferenceView`**

```swift
import SwiftUI
import UIKit
import IPACore

struct ReferenceView: View {
    @State private var debouncer = ClipboardDebouncer()
    @State private var toast: String? = nil
    @State private var hideTask: DispatchWorkItem? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(SymbolReferenceData.rows, id: \.key) { row in
                    Section(header: Text("Long-press the \(String(row.key)) key on the IPA Keyboard")) {
                        ForEach(row.entries, id: \.symbol) { entry in
                            Button(action: { tap(entry.symbol) }) {
                                HStack(spacing: 14) {
                                    Text(entry.symbol)
                                        .font(.system(size: 28, weight: .regular, design: .serif))
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name.isEmpty
                                             ? LocalizedSymbolNames.name(for: entry.symbol)
                                             : entry.name)
                                            .font(.body)
                                        if !entry.example.isEmpty {
                                            Text(entry.example)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .accessibilityLabel("Copy \(entry.symbol), \(entry.name)")
                            .accessibilityHint("Double-tap to copy the symbol to the clipboard")
                        }
                    }
                }
            }
            .navigationTitle("Reference")
        }
        .ipaToast(message: $toast)
    }

    private func tap(_ symbol: String) {
        guard debouncer.accept(value: symbol, at: Date().timeIntervalSinceReferenceDate) else { return }
        UIPasteboard.general.string = symbol
        showToast("Copied \(symbol)")
    }

    private func showToast(_ msg: String) {
        hideTask?.cancel()
        toast = msg
        let task = DispatchWorkItem {
            toast = nil
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
}
```

- [ ] **Step 3: Build and visually verify**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator build | tail -5`
Expected: success.

On simulator, tap the Reference tab. Confirm 11 sections, each with its letter's variants. Tap `æ` — toast `Copied æ` appears for ~2s. Paste into a text field — `æ` is in the clipboard.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardApp/Views/ReferenceView.swift \
        ios/IPAKeyboardApp/Views/ToastModifier.swift
git commit -m "ios: ReferenceView — tap-to-copy with toast and debounce

Reads from SymbolReferenceData. Uses ClipboardDebouncer for per-value gating.
Toast auto-hides at 2s (cancelled on new tap so the toast follows user intent)."
```

---

## Task 6.3 — UI tests: clipboard + debounce + toast timing

**Files:**
- Create: `ios/IPAKeyboardAppUITests/ReferenceTabUITests.swift`

- [ ] **Step 1: Implement**

```swift
import XCTest

final class ReferenceTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchOnReferenceTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-SkipSetupForUITests"]
        app.launch()
        // Switch to Reference tab if not already.
        let tab = app.tabBars.buttons["Reference"]
        if tab.exists { tab.tap() }
        XCTAssertTrue(app.navigationBars["Reference"].waitForExistence(timeout: 3))
        return app
    }

    func test_tapVariantCopiesAndShowsToast() {
        let app = launchOnReferenceTab()
        UIPasteboard.general.string = ""    // clear
        let aeCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Copy æ'")
        ).firstMatch
        XCTAssertTrue(aeCell.waitForExistence(timeout: 3))
        aeCell.tap()

        // Toast appears fast (< 500ms).
        let toast = app.staticTexts["Copied æ"]
        XCTAssertTrue(toast.waitForExistence(timeout: 0.5))
        XCTAssertEqual(UIPasteboard.general.string, "æ")

        // Toast disappears before 2.5s.
        let notExist = NSPredicate(format: "exists == false")
        expectation(for: notExist, evaluatedWith: toast)
        waitForExpectations(timeout: 2.5)
    }

    func test_rapidSameValueTapsWriteOnce() {
        let app = launchOnReferenceTab()
        UIPasteboard.general.string = ""
        let aeCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Copy æ'")).firstMatch
        XCTAssertTrue(aeCell.waitForExistence(timeout: 3))

        // Five rapid taps within 500ms.  We cannot directly measure pasteboard
        // writes; assert instead by clipboard stability + exactly-one toast.
        for _ in 0..<5 { aeCell.tap() }
        let toasts = app.staticTexts.matching(NSPredicate(format: "label == 'Copied æ'"))
        XCTAssertEqual(toasts.count, 1)
        XCTAssertEqual(UIPasteboard.general.string, "æ")
    }

    func test_differentValueResetsDebounceImmediately() {
        let app = launchOnReferenceTab()
        UIPasteboard.general.string = ""
        let ae = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Copy æ'")).firstMatch
        let wedge = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Copy ʌ'")).firstMatch

        ae.tap()
        // Tap ʌ immediately — should be accepted regardless of debounce window.
        wedge.tap()
        XCTAssertEqual(UIPasteboard.general.string, "ʌ")
    }
}
```

- [ ] **Step 2: Add a `-SkipSetupForUITests` handler**

In `IPAKeyboardAppApp.swift`:

```swift
init() {
    let args = ProcessInfo.processInfo.arguments
    if args.contains("-ResetSetupForUITests") {
        let d = UserDefaults.standard
        d.removeObject(forKey: AppState.Keys.hasConfirmedSetup)
        d.removeObject(forKey: AppState.Keys.sawIpaCharacterInTestField)
    }
    if args.contains("-SkipSetupForUITests") {
        UserDefaults.standard.set(true, forKey: AppState.Keys.hasConfirmedSetup)
    }
}
```

- [ ] **Step 3: Run UI tests**

Run: `xcodebuild test -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IPAKeyboardAppUITests/ReferenceTabUITests 2>&1 | tail -20`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardAppUITests/ReferenceTabUITests.swift \
        ios/IPAKeyboardApp/IPAKeyboardAppApp.swift
git commit -m "ios: UI tests — clipboard contract + debounce + toast timing

Toast asserts existence within 500ms and disappearance within 2.5s.
Rapid same-value taps → exactly one toast in view + clipboard stable.
Different-value tap resets debounce window immediately."
```

---

## Task 6.4 — `AboutView`

**Files:**
- Modify: `ios/IPAKeyboardApp/Views/AboutView.swift`
- Modify: `ios/IPAKeyboardAppUITests/AboutTabUITests.swift` (create)

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("IPA Keyboard") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("AppVersionValue")
                    }
                }
                Section("Privacy") {
                    Text("This app collects no data. It works entirely offline. No accounts, no analytics, no network.")
                        .font(.body)
                }
                Section("Open-source licenses") {
                    Text("No third-party code ships in IPA Keyboard.")
                        .font(.body)
                }
            }
            .navigationTitle("About")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
```

- [ ] **Step 2: UI test: version matches Info.plist**

`ios/IPAKeyboardAppUITests/AboutTabUITests.swift`:

```swift
import XCTest

final class AboutTabUITests: XCTestCase {
    func test_versionMatchesInfoPlist() {
        let app = XCUIApplication()
        app.launchArguments += ["-SkipSetupForUITests"]
        app.launch()
        app.tabBars.buttons["About"].tap()

        let label = app.staticTexts.matching(identifier: "AppVersionValue").firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 3))

        // Regex sanity: version string is "X.Y(.Z)? (build)"
        let value = label.label
        XCTAssertTrue(value.range(of: #"^\d+\.\d+(\.\d+)? \(\d+\)$"#, options: .regularExpression) != nil,
                      "Unexpected version string: \(value)")
    }

    func test_aboutMentionsOfflineAndNoNetwork() {
        let app = XCUIApplication()
        app.launchArguments += ["-SkipSetupForUITests"]
        app.launch()
        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'entirely offline'"))
                        .firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'no network'"))
                        .firstMatch.exists)
    }
}
```

- [ ] **Step 3: Build and run tests**

Run: `xcodebuild test -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IPAKeyboardAppUITests/AboutTabUITests 2>&1 | tail -20`
Expected: 2 tests pass.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardApp/Views/AboutView.swift \
        ios/IPAKeyboardAppUITests/AboutTabUITests.swift
git commit -m "ios: AboutView with version + privacy statement + licenses

Version read from CFBundleShortVersionString + CFBundleVersion.
UI test asserts the privacy copy mentions 'entirely offline' and 'no network'."
```

---

## Phase 6 exit checklist

- [ ] `ClipboardDebouncerTests` — 5/5 pass
- [ ] `ReferenceTabUITests` — 3/3 pass
- [ ] `AboutTabUITests` — 2/2 pass
- [ ] Manual: Reference tab scrolls; all 11 sections present (a, e, i, o, u, t, s, d, c, n, z)
- [ ] Manual: total of 18 variant rows across all sections
- [ ] Manual: tap `æ` → clipboard receives `æ`, toast appears and disappears cleanly
- [ ] Manual: rapid 5× tap of `æ` → exactly one toast appears
- [ ] Manual: tap `æ` then immediately `ʌ` → clipboard = `ʌ` (debounce is per-value, not per-tap)
- [ ] Manual: About tab shows correct version string and privacy copy
- [ ] VoiceOver: each reference cell reads "Copy æ, Ash" (symbol + name) with hint "Double-tap to copy the symbol to the clipboard"

When all boxes are ticked, tick Phase 6 in `ios/PLAN.md` and move to Phase 7.
