# Phase 4 — Numbers / symbols layers + coach-mark banner

**Ships:** `123` numbers layer and `#+=` symbols layer (iOS-standard content, no IPA on these layers). Layer switching via the `123` / `ABC` / `#+=` keys. Coach-mark banner that shows for ≤4s during the first 3 keyboard activations, persisted in the extension's own `UserDefaults`.

**Spec sections:** §4.1 layout (numbers/symbols layer), §4.2 (layer switch), §4.6 coach mark, §4.7 memory budget.

**Pre-req:** Phase 3 complete. `KeyboardRootView` drives alpha layer + popovers end-to-end.

---

## Task 4.1 — `KeyboardLayer` enum + refactor `KeyboardRootView` to own layer state

**Files:**
- Modify: `ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`

- [ ] **Step 1: Introduce the layer enum**

At top of `KeyboardRootView.swift`:

```swift
enum KeyboardLayer {
    case alpha
    case numbers        // "123" — digits + common punctuation
    case symbols        // "#+=" — symbols
}
```

- [ ] **Step 2: Add `@State var layer: KeyboardLayer = .alpha` to `KeyboardRootView`**

Add near the other `@State` declarations.

- [ ] **Step 3: Replace the single alpha body with a switch**

Replace the body of `keyboardBody(in:)` with:

```swift
private func keyboardBody(in size: CGSize) -> some View {
    VStack(spacing: 6) {
        switch layer {
        case .alpha:
            alphaContent
        case .numbers:
            NumbersLayerView(
                isShifted: false,
                onInsertText: { text in onInsertText(text) },
                onDeleteBackward: onDeleteBackward,
                onSwitchToAlpha: { layer = .alpha },
                onSwitchToSymbols: { layer = .symbols },
                onAdvanceInputMode: onAdvanceInputMode
            )
        case .symbols:
            SymbolsLayerView(
                onInsertText: { text in onInsertText(text) },
                onDeleteBackward: onDeleteBackward,
                onSwitchToAlpha: { layer = .alpha },
                onSwitchToNumbers: { layer = .numbers },
                onAdvanceInputMode: onAdvanceInputMode
            )
        }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
}

// Promote the previous alpha body into a computed property:
private var alphaContent: some View {
    Group {
        row(row1, rowIndex: 0)
        HStack {
            Spacer(minLength: 18)
            row(row2, rowIndex: 1)
            Spacer(minLength: 18)
        }
        row3Bar
        alphaFunctionRow
    }
}
```

- [ ] **Step 4: Rename the existing `functionRow` → `alphaFunctionRow`, change the `123` key to flip the layer**

```swift
private var alphaFunctionRow: some View {
    HStack(spacing: 5) {
        KeyView(label: "123", style: .function, showsDot: false, onTap: { layer = .numbers })
            .frame(maxWidth: 44, maxHeight: .infinity)
        KeyView(label: "🌐", style: .function, showsDot: false, onTap: onAdvanceInputMode)
            .frame(maxWidth: 44, maxHeight: .infinity)
        KeyView(label: "space", style: .function, showsDot: false, onTap: { onInsertText(" ") })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        KeyView(label: "return", style: .returnKey, showsDot: false, onTap: { onInsertText("\n") })
            .frame(maxWidth: 64, maxHeight: .infinity)
    }
    .frame(height: rowHeight)
}
```

- [ ] **Step 5: Build (will fail — `NumbersLayerView` / `SymbolsLayerView` not yet defined)**

Skip running build; we write those next.

---

## Task 4.2 — `NumbersLayerView` (123 digits + punctuation)

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/NumbersLayerView.swift`

Matching iOS's stock 123 layer: top row `1234567890`, middle row `-/:;()$&@"`, bottom row has `#+=` toggle, `.,?!'`, backspace.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct NumbersLayerView: View {
    let isShifted: Bool
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onSwitchToAlpha: () -> Void
    let onSwitchToSymbols: () -> Void
    let onAdvanceInputMode: () -> Void

    private let row1: [String] = ["1","2","3","4","5","6","7","8","9","0"]
    private let row2: [String] = ["-","/",":",";","(",")","$","&","@","\""]
    private let row3: [String] = [".",",","?","!","'"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) { ForEach(row1, id: \.self) { cell($0) } }
                .frame(height: rowHeight)
            HStack(spacing: 5) { ForEach(row2, id: \.self) { cell($0) } }
                .frame(height: rowHeight)
            HStack(spacing: 5) {
                KeyView(label: "#+=", style: .function, showsDot: false,
                        onTap: onSwitchToSymbols)
                    .frame(maxWidth: 52, maxHeight: .infinity)
                ForEach(row3, id: \.self) { cell($0) }
                KeyView(label: "⌫", style: .function, showsDot: false,
                        onTap: onDeleteBackward)
                    .frame(maxWidth: 44, maxHeight: .infinity)
            }
            .frame(height: rowHeight)
            HStack(spacing: 5) {
                KeyView(label: "ABC", style: .function, showsDot: false, onTap: onSwitchToAlpha)
                    .frame(maxWidth: 52, maxHeight: .infinity)
                KeyView(label: "🌐", style: .function, showsDot: false,
                        onTap: onAdvanceInputMode)
                    .frame(maxWidth: 44, maxHeight: .infinity)
                KeyView(label: "space", style: .function, showsDot: false,
                        onTap: { onInsertText(" ") })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                KeyView(label: "return", style: .returnKey, showsDot: false,
                        onTap: { onInsertText("\n") })
                    .frame(maxWidth: 64, maxHeight: .infinity)
            }
            .frame(height: rowHeight)
        }
    }

    private func cell(_ s: String) -> some View {
        KeyView(label: s, style: .letter, showsDot: false, onTap: { onInsertText(s) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }
        if vSize == .compact { return 38 }
        return 44
    }
}
```

---

## Task 4.3 — `SymbolsLayerView` (#+= symbols)

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/SymbolsLayerView.swift`

Content matches iOS stock `#+=`: `[`, `]`, `{`, `}`, `#`, `%`, `^`, `*`, `+`, `=`, then `_`, `\`, `|`, `~`, `<`, `>`, `€`, `£`, `¥`, `•`, then `.`, `,`, `?`, `!`, `'`.

- [ ] **Step 1: Implement (mirror structure of `NumbersLayerView`)**

```swift
import SwiftUI

struct SymbolsLayerView: View {
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onSwitchToAlpha: () -> Void
    let onSwitchToNumbers: () -> Void
    let onAdvanceInputMode: () -> Void

    private let row1: [String] = ["[","]","{","}","#","%","^","*","+","="]
    private let row2: [String] = ["_","\\","|","~","<",">","€","£","¥","•"]
    private let row3: [String] = [".",",","?","!","'"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) { ForEach(row1, id: \.self) { cell($0) } }
                .frame(height: rowHeight)
            HStack(spacing: 5) { ForEach(row2, id: \.self) { cell($0) } }
                .frame(height: rowHeight)
            HStack(spacing: 5) {
                KeyView(label: "123", style: .function, showsDot: false,
                        onTap: onSwitchToNumbers)
                    .frame(maxWidth: 52, maxHeight: .infinity)
                ForEach(row3, id: \.self) { cell($0) }
                KeyView(label: "⌫", style: .function, showsDot: false,
                        onTap: onDeleteBackward)
                    .frame(maxWidth: 44, maxHeight: .infinity)
            }
            .frame(height: rowHeight)
            HStack(spacing: 5) {
                KeyView(label: "ABC", style: .function, showsDot: false, onTap: onSwitchToAlpha)
                    .frame(maxWidth: 52, maxHeight: .infinity)
                KeyView(label: "🌐", style: .function, showsDot: false,
                        onTap: onAdvanceInputMode)
                    .frame(maxWidth: 44, maxHeight: .infinity)
                KeyView(label: "space", style: .function, showsDot: false,
                        onTap: { onInsertText(" ") })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                KeyView(label: "return", style: .returnKey, showsDot: false,
                        onTap: { onInsertText("\n") })
                    .frame(maxWidth: 64, maxHeight: .infinity)
            }
            .frame(height: rowHeight)
        }
    }

    private func cell(_ s: String) -> some View {
        KeyView(label: s, style: .letter, showsDot: false, onTap: { onInsertText(s) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }
        if vSize == .compact { return 38 }
        return 44
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verify layer cycle**

In simulator: tap `123` → numbers layer appears. Tap `#+=` → symbols layer appears. Tap `ABC` → back to alpha. Type `1`, `#`, `€` — verify each inserts. Tap backspace — verify each deletes. Tap globe from any layer — cycles away cleanly.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardExtension/Views/
git commit -m "ios: numbers (123) and symbols (#+=) layers

Layer state lives in KeyboardRootView. Content matches stock iOS keyboard.
No IPA on these layers — plain punctuation."
```

---

## Task 4.4 — Snapshot coverage for numbers + symbols layers

**Files:**
- Modify: `ios/Tests/KeyboardExtensionSnapshotTests/KeyboardSnapshotTests.swift`

- [ ] **Step 1: Add tests**

```swift
    // Numbers layer
    func test_numbers_iPhone15_light() {
        let view = NumbersLayerView(
            isShifted: false,
            onInsertText: { _ in }, onDeleteBackward: {},
            onSwitchToAlpha: {}, onSwitchToSymbols: {}, onAdvanceInputMode: {}
        ).frame(width: 393, height: 220)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13))
    }

    // Symbols layer
    func test_symbols_iPhone15_light() {
        let view = SymbolsLayerView(
            onInsertText: { _ in }, onDeleteBackward: {},
            onSwitchToAlpha: {}, onSwitchToNumbers: {}, onAdvanceInputMode: {}
        ).frame(width: 393, height: 220)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13))
    }

    // Dark mode sanity on numbers layer
    func test_numbers_iPhone15_dark() {
        let view = NumbersLayerView(
            isShifted: false,
            onInsertText: { _ in }, onDeleteBackward: {},
            onSwitchToAlpha: {}, onSwitchToSymbols: {}, onAdvanceInputMode: {}
        ).frame(width: 393, height: 220)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .dark))
        )
    }
```

- [ ] **Step 2: Record baselines, verify clean renders**

Set `isRecording = true`, run tests, inspect PNGs, set back to `false`, confirm PASS.

- [ ] **Step 3: Commit**

```bash
git add ios/Tests/KeyboardExtensionSnapshotTests/
git commit -m "ios: snapshot tests — numbers + symbols layers light/dark"
```

---

## Task 4.5 — `CoachMarkBanner` + activation count

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/CoachMarkBanner.swift`
- Modify: `ios/IPAKeyboardExtension/KeyboardViewController.swift`
- Modify: `ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`

- [ ] **Step 1: Implement the banner**

`ios/IPAKeyboardExtension/Views/CoachMarkBanner.swift`:

```swift
import SwiftUI

struct CoachMarkBanner: View {
    var body: some View {
        Text("Long-press dotted keys for IPA · Open IPA Keyboard app for help")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .accessibilityLabel("Tip: long-press dotted keys to type IPA variants")
    }
}

#Preview { CoachMarkBanner().padding() }
```

- [ ] **Step 2: Bump `activationCount` in `KeyboardViewController`**

Add to `KeyboardViewController`:

```swift
extension KeyboardViewController {
    static let activationCountKey = "ipa.activationCount"

    func incrementActivationCount() -> Int {
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: Self.activationCountKey) + 1
        defaults.set(next, forKey: Self.activationCountKey)
        return next
    }

    /// Call from viewWillAppear.
    func readActivationCount() -> Int {
        UserDefaults.standard.integer(forKey: Self.activationCountKey)
    }
}
```

And in `viewWillAppear`:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let count = incrementActivationCount()
    NotificationCenter.default.post(
        name: .ipaKeyboardActivationCountChanged,
        object: nil,
        userInfo: ["count": count]
    )
}
```

Add the notification:

```swift
extension Notification.Name {
    static let ipaKeyboardActivationCountChanged = Notification.Name("ipa.activationCount.changed")
}
```

- [ ] **Step 3: Observe in `KeyboardRootView` and render the banner**

Add to `KeyboardRootView`:

```swift
@State private var activationCount: Int = 0
@State private var coachMarkVisible: Bool = false
```

Inside `body`'s outermost `ZStack`, add below the keyboard:

```swift
if coachMarkVisible {
    VStack {
        CoachMarkBanner()
            .padding(.top, 2)
        Spacer()
    }
    .transition(.opacity)
    .allowsHitTesting(false)
}
```

At end of body's modifier chain, add observer:

```swift
.onReceive(NotificationCenter.default.publisher(for: .ipaKeyboardActivationCountChanged)) { note in
    let count = note.userInfo?["count"] as? Int ?? 0
    activationCount = count
    if count <= 3 {
        withAnimation(.easeIn(duration: 0.2)) { coachMarkVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 0.2)) { coachMarkVisible = false }
        }
    }
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
    coachMarkVisible = false
}
```

And in `beginPress`, add at the top:

```swift
// Any key press dismisses the coach mark.
if coachMarkVisible {
    withAnimation(.easeOut(duration: 0.2)) { coachMarkVisible = false }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual verify the 3-activation budget**

On simulator: reset the extension's UserDefaults (reinstall the app from Xcode). Open Notes with IPA Keyboard — banner visible for ~4s on first activation. Tap any key — banner fades immediately. Switch keyboards and back: banner visible (activation #2) — tap to dismiss. Switch away and back: banner visible (activation #3). Switch away and back a 4th time: **no banner**. Kill the simulator, reinstall, confirm banner returns (counter is per-install, not session).

- [ ] **Step 6: Commit**

```bash
git add ios/IPAKeyboardExtension/
git commit -m "ios: coach-mark banner for first 3 activations

activationCount lives in extension UserDefaults (no App Group).
Banner auto-dismisses after ~4s or on first key press.
Shown in the prediction-bar zone so layout cost is zero."
```

---

## Task 4.6 — Unit test the coach-mark counter logic

**Files:**
- Create: `ios/IPACore/Sources/IPACore/CoachMarkPolicy.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/CoachMarkPolicyTests.swift`

Pull the "show if count ≤ 3" rule out of the view and into `IPACore` so it's testable.

- [ ] **Step 1: Failing tests first**

```swift
import XCTest
@testable import IPACore

final class CoachMarkPolicyTests: XCTestCase {
    func test_showOnFirstThreeActivations() {
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 1))
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 2))
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 3))
    }
    func test_hiddenForLaterActivations() {
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 4))
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 500))
    }
    func test_hiddenForZeroOrNegative() {
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 0))
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: -1))
    }
    func test_autoDismissAfterFourSeconds() {
        XCTAssertEqual(CoachMarkPolicy.autoDismissDelay, 4.0, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation

public enum CoachMarkPolicy {
    public static let showThreshold: Int = 3
    public static let autoDismissDelay: TimeInterval = 4.0

    public static func shouldShow(forActivationCount count: Int) -> Bool {
        (1...showThreshold).contains(count)
    }
}
```

- [ ] **Step 3: Replace the `count <= 3` and `4`-second literals in `KeyboardRootView`**

In the `onReceive`:

```swift
if CoachMarkPolicy.shouldShow(forActivationCount: count) {
    withAnimation(.easeIn(duration: 0.2)) { coachMarkVisible = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + CoachMarkPolicy.autoDismissDelay) {
        withAnimation(.easeOut(duration: 0.2)) { coachMarkVisible = false }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd ios/IPACore && swift test --filter CoachMarkPolicyTests 2>&1 | tail -10`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/IPACore/ ios/IPAKeyboardExtension/Views/KeyboardRootView.swift
git commit -m "ios: extract CoachMarkPolicy to IPACore with tests

View layer now references CoachMarkPolicy.showThreshold and autoDismissDelay
instead of literals. Makes intent reviewable and policy testable."
```

---

## Phase 4 exit checklist

- [ ] `swift test` — all existing tests plus `CoachMarkPolicyTests` green
- [ ] Snapshot tests for numbers and symbols layers pass (light + dark for numbers)
- [ ] Manual: `123` → numbers layer, `#+=` → symbols, `ABC` → back to alpha, all transitions clean
- [ ] Manual: typing numbers / punctuation inserts correct characters
- [ ] Manual: first 3 keyboard activations show the coach-mark banner; 4th does not
- [ ] Manual: any key press or keyboard-hide dismisses the banner immediately
- [ ] `UserDefaults.standard` write for `activationCount` persists across simulator relaunches

When all boxes are ticked, tick Phase 4 in `ios/PLAN.md` and move to Phase 5.
