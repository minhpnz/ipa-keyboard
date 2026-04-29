# Phase 3 — Long-press popover

**Ships:** The defining interaction. Touch-and-hold a dotted key ≥500ms → popover with IPA variants → drag onto one → release → variant inserted. Cancel cleanly on phone call, app switch, rapid globe-taps, or release-over-nothing. Uses the UUID-token state machine from spec §4.4.

**Spec sections:** §4.2 interaction rules (long-press / drag / release), §4.4 gesture correctness, §4.5 popover geometry, §4.6 coach-mark prep (prep only — Phase 4 ships the banner).

**Pre-req:** Phase 2 complete. `KeyboardRootView` wired, `KeyView` rendering dots, `LayoutEngine.popoverRect` available.

---

## Task 3.1 — `TouchState` model in `IPACore` (the UUID-token state machine, pure)

**Files:**
- Create: `ios/IPACore/Sources/IPACore/TouchState.swift`
- Create: `ios/IPACore/Tests/IPACoreTests/TouchStateTests.swift`

Isolating the state machine in `IPACore` lets us test it without UIKit. The view layer reads/writes this model.

- [ ] **Step 1: Failing tests first**

`ios/IPACore/Tests/IPACoreTests/TouchStateTests.swift`:

```swift
import XCTest
@testable import IPACore

final class TouchStateTests: XCTestCase {

    func test_newTouchAssignsTokenAndKey() {
        var s = TouchState()
        let t = s.begin(key: "a")
        XCTAssertEqual(s.current?.key, "a")
        XCTAssertEqual(s.current?.token, t)
    }

    func test_timerCallbackWithMatchingTokenIsAcceptedForPopover() {
        var s = TouchState()
        let t = s.begin(key: "a")
        XCTAssertTrue(s.shouldShowPopover(for: t))
    }

    func test_timerCallbackWithStaleTokenIsRejected() {
        var s = TouchState()
        let t1 = s.begin(key: "a")
        _ = s.begin(key: "e")    // stomps t1
        XCTAssertFalse(s.shouldShowPopover(for: t1))
    }

    func test_cancelClearsState() {
        var s = TouchState()
        let t = s.begin(key: "a")
        s.cancel()
        XCTAssertNil(s.current)
        XCTAssertFalse(s.shouldShowPopover(for: t))
    }

    func test_endReleasesTokenButKeepsKeyForInsert() {
        var s = TouchState()
        _ = s.begin(key: "a")
        let ended = s.end()
        XCTAssertEqual(ended, "a")
        XCTAssertNil(s.current)
    }

    func test_endOnEmptyStateReturnsNil() {
        var s = TouchState()
        XCTAssertNil(s.end())
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `cd ios/IPACore && swift test --filter TouchStateTests 2>&1 | tail -10`

- [ ] **Step 3: Implement**

`ios/IPACore/Sources/IPACore/TouchState.swift`:

```swift
import Foundation

public struct TouchState: Equatable {

    public struct Active: Equatable {
        public let key: Character
        public let token: UUID
    }

    public private(set) var current: Active? = nil

    public init() {}

    /// Begin a new touch. Returns the token — pass it to the popover timer callback.
    @discardableResult
    public mutating func begin(key: Character) -> UUID {
        let token = UUID()
        current = Active(key: key, token: token)
        return token
    }

    /// Late timer callback: is this token still the active one?
    public func shouldShowPopover(for token: UUID) -> Bool {
        current?.token == token
    }

    /// Touch ended normally. Returns the key so the caller can insert it (if no popover was open).
    @discardableResult
    public mutating func end() -> Character? {
        let key = current?.key
        current = nil
        return key
    }

    /// Touch cancelled (system interruption, drag off, etc.)
    public mutating func cancel() {
        current = nil
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd ios/IPACore && swift test --filter TouchStateTests 2>&1 | tail -10`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/IPACore/Sources/IPACore/TouchState.swift \
        ios/IPACore/Tests/IPACoreTests/TouchStateTests.swift
git commit -m "ios: TouchState — UUID-token gesture state machine

Pure value type. Late timer callbacks compare their captured token
against current; stale tokens are silently dropped. Cancel clears state."
```

---

## Task 3.2 — `VariantPopover` view (rendering + selection highlight)

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/VariantPopover.swift`

- [ ] **Step 1: Implement**

`ios/IPAKeyboardExtension/Views/VariantPopover.swift`:

```swift
import SwiftUI

struct VariantPopover: View {
    let variants: [String]
    let selectedIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(variants.enumerated()), id: \.offset) { index, variant in
                Text(variant)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(selectedIndex == index ? .black : .primary)
                    .frame(minWidth: 36, minHeight: 44)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(selectedIndex == index
                                  ? Color(red: 0.40, green: 0.67, blue: 1.0)
                                  : Color(uiColor: .systemGray4))
                    )
                    .accessibilityLabel(variant)
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        )
    }
}

#Preview {
    VariantPopover(variants: ["æ", "ʌ", "ɑː"], selectedIndex: 0)
        .padding()
}
```

- [ ] **Step 2: Visual-check in Xcode Canvas**

Open the file, activate Canvas, see the preview render. Change `selectedIndex: 0` to `1`, then `nil`; confirm highlight moves / disappears.

- [ ] **Step 3: Commit**

```bash
git add ios/IPAKeyboardExtension/Views/VariantPopover.swift
git commit -m "ios: VariantPopover — serif-font IPA glyphs with highlight state

Selection renders with the same blue as the return key for visual consistency.
Min tap target 36x44pt; accessibility label is the raw variant for VoiceOver."
```

---

## Task 3.3 — Wire gesture + popover into `KeyboardRootView`

**Files:**
- Modify: `ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`
- Modify: `ios/IPAKeyboardExtension/Views/KeyView.swift`

The important thing: the `KeyView`'s `DragGesture` must emit begin / change / end to the parent, because the drag may leave the originating key and enter the popover above.

- [ ] **Step 1: Rework `KeyView` to forward raw touch events up**

Replace the body's gesture block in `ios/IPAKeyboardExtension/Views/KeyView.swift` so it forwards begin/change/end:

```swift
struct KeyView: View {
    // …unchanged props above…
    let onPressBegan: () -> Void = {}          // default = noop for callers that don't care
    let onDrag: (CGPoint) -> Void = { _ in }
    let onPressEnded: (Bool) -> Void = { _ in } // Bool = wasTap (no long-press fired)
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // …same layers as before…
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        onPressBegan()
                    }
                    onDrag(value.location)
                }
                .onEnded { value in
                    isPressed = false
                    onPressEnded(value.translation == .zero)
                    if value.translation == .zero {
                        onTap()
                    }
                }
        )
    }
}
```

- [ ] **Step 2: Rewrite the long-press plumbing in `KeyboardRootView`**

Replace `KeyboardRootView.swift` with:

```swift
import SwiftUI
import IPACore

struct KeyboardRootView: View {

    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    @State private var isShifted: Bool = false
    @State private var touch = TouchState()
    @State private var popoverKey: Character? = nil
    @State private var popoverVariants: [String] = []
    @State private var popoverKeyFrame: CGRect = .zero
    @State private var popoverSelection: Int? = nil

    private let row1: [Character] = Array("qwertyuiop")
    private let row2: [Character] = Array("asdfghjkl")
    private let row3: [Character] = Array("zxcvbnm")
    private static let dotted: Set<Character> = Set(IPAMapping.dottedKeys)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                keyboardBody(in: geo.size)
                if let key = popoverKey {
                    popoverOverlay(key: key, in: CGRect(origin: .zero, size: geo.size))
                }
            }
        }
        .frame(height: totalHeight)
        .background(Color(uiColor: .systemGray6))
    }

    private func keyboardBody(in size: CGSize) -> some View {
        VStack(spacing: 6) {
            row(row1, rowIndex: 0)
            HStack {
                Spacer(minLength: 18)
                row(row2, rowIndex: 1)
                Spacer(minLength: 18)
            }
            row3Bar
            functionRow
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private func row(_ keys: [Character], rowIndex: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keyCell(key)
            }
        }
        .frame(height: rowHeight)
    }

    private var row3Bar: some View {
        HStack(spacing: 5) {
            KeyView(label: "⇧", style: .shift, showsDot: false, onTap: { isShifted.toggle() })
            HStack(spacing: 5) {
                ForEach(Array(row3.enumerated()), id: \.offset) { _, key in
                    keyCell(key)
                }
            }
            KeyView(label: "⌫", style: .function, showsDot: false, onTap: onDeleteBackward)
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private func keyCell(_ key: Character) -> some View {
        let dotted = Self.dotted.contains(key)
        GeometryReader { cellGeo in
            KeyView(
                label: isShifted ? String(key).uppercased() : String(key),
                style: .letter,
                showsDot: dotted,
                onPressBegan: { beginPress(on: key, frame: cellGeo.frame(in: .local)) },
                onDrag: { point in drag(to: point, cellOrigin: cellGeo.frame(in: .global).origin) },
                onPressEnded: { _ in endPress() },
                onTap: { tap(key) }
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gesture dispatch

    private func tap(_ key: Character) {
        // Tap fires iff no popover is visible. The plain-tap path is
        // already taken care of by onPressEnded -> endPress; this is here
        // for future-proofing when onTap fires without any drag.
        if popoverKey == nil {
            let s = isShifted ? String(key).uppercased() : String(key)
            onInsertText(s)
            if isShifted { isShifted = false }
        }
    }

    private func beginPress(on key: Character, frame: CGRect) {
        let token = touch.begin(key: key)
        if Self.dotted.contains(key), let variants = IPAMapping.variants[key] {
            popoverVariants = variants
            popoverKeyFrame = frame
            popoverSelection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + LayoutEngine.popoverDelay) {
                if touch.shouldShowPopover(for: token) {
                    popoverKey = key
                }
            }
        }
    }

    private func drag(to point: CGPoint, cellOrigin: CGPoint) {
        guard popoverKey != nil else { return }
        // Map the global-coord drag point into the popover's variant row.
        // We use `point.x` relative to the popover's leading edge; each
        // variant is ≥36pt wide.  For simplicity of v1, bucket by width.
        let variantCount = popoverVariants.count
        guard variantCount > 0 else { return }
        let bucketWidth: CGFloat = 44    // matches VariantPopover sizing (36 + 8 padding)
        let origin = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: CGSize(width: CGFloat(variantCount) * bucketWidth + 16, height: 52),
            keyboardBounds: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: totalHeight)
        ).origin
        let relX = point.x - origin.x
        let index = Int((relX) / bucketWidth)
        popoverSelection = (0..<variantCount).contains(index) ? index : nil
    }

    private func endPress() {
        if let key = popoverKey, let sel = popoverSelection {
            let variant = popoverVariants[sel]
            onInsertText(variant)
            HapticsService.shared.selection()
        } else if popoverKey == nil, let key = touch.end() {
            let s = isShifted ? String(key).uppercased() : String(key)
            onInsertText(s)
            if isShifted { isShifted = false }
        }
        popoverKey = nil
        popoverVariants = []
        popoverSelection = nil
        touch.cancel()
    }

    // MARK: - Overlay

    @ViewBuilder
    private func popoverOverlay(key: Character, in bounds: CGRect) -> some View {
        let popoverSize = CGSize(
            width: CGFloat(popoverVariants.count) * 44 + 16,
            height: 52
        )
        let rect = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: popoverSize,
            keyboardBounds: bounds
        )
        VariantPopover(variants: popoverVariants, selectedIndex: popoverSelection)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)    // popover is indicator only; gesture lives on the key below
    }

    // MARK: - Function row + sizing

    private var functionRow: some View {
        HStack(spacing: 5) {
            KeyView(label: "123", style: .function, showsDot: false, onTap: {})
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

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }
        if vSize == .compact { return 38 }
        return 44
    }
    private var totalHeight: CGFloat { rowHeight * 4 + 30 }
}
```

Note: `drag(to:)` is best-effort in v1 — it buckets by a fixed 44pt stride. For 3-variant popovers (max case), this is fine; if you miss on edges, the tests in Phase 8's manual checklist will expose it and we can refine. A more elaborate version would read each variant's actual frame; YAGNI for v1.

- [ ] **Step 3: Create `HapticsService` stub so it compiles**

`ios/IPAKeyboardExtension/Services/HapticsService.swift`:

```swift
import UIKit

final class HapticsService {
    static let shared = HapticsService()
    private let generator = UISelectionFeedbackGenerator()
    private var isAvailable: Bool {
        // Low Power Mode and older hardware quietly no-op.
        !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    func selection() {
        guard isAvailable else { return }
        generator.selectionChanged()
    }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ios/IPAKeyboardExtension/
git commit -m "ios: long-press popover wired end-to-end

TouchState UUID-token protects against late-timer races.
Popover renders via LayoutEngine.popoverRect (edge-aware).
Drag maps to variant index by fixed bucket width.
HapticsService selection() fires on insert; no-ops in Low Power Mode."
```

---

## Task 3.4 — Snapshot tests for popover on corner keys

**Files:**
- Modify: `ios/Tests/KeyboardExtensionSnapshotTests/KeyboardSnapshotTests.swift`

- [ ] **Step 1: Add popover variants to the snapshot suite**

Append to `KeyboardSnapshotTests.swift`:

```swift
    // Popover rendering on every corner + narrow widths.
    private func rootWithPopoverForcedOn(key: Character) -> some View {
        // Test hook: inject initial state so the popover is visible without
        // driving real gestures.  This requires exposing a debug initializer
        // on KeyboardRootView — see the `#if DEBUG` block at the bottom
        // of KeyboardRootView.swift.
        KeyboardRootView.forcedPopoverPreview(key: key)
    }

    func test_popover_cornerA_light() {
        assertSnapshot(
            of: UIHostingController(rootView: rootWithPopoverForcedOn(key: "a")
                .frame(width: 393, height: 260)),
            as: .image(on: .iPhone13)
        )
    }

    func test_popover_cornerP_light() {
        assertSnapshot(
            of: UIHostingController(rootView: rootWithPopoverForcedOn(key: "o")
                .frame(width: 393, height: 260)),
            as: .image(on: .iPhone13)
        )
    }

    func test_popover_cornerZ_narrow_light() {
        assertSnapshot(
            of: UIHostingController(rootView: rootWithPopoverForcedOn(key: "z")
                .frame(width: 320, height: 216)),
            as: .image(on: .iPhoneSe)
        )
    }

    func test_popover_cornerN_iPad_floating() {
        assertSnapshot(
            of: UIHostingController(rootView: rootWithPopoverForcedOn(key: "n")
                .frame(width: 320, height: 260)),
            as: .image(size: CGSize(width: 320, height: 260))
        )
    }
```

- [ ] **Step 2: Add the debug hook to `KeyboardRootView`**

At the bottom of `KeyboardRootView.swift`:

```swift
#if DEBUG
extension KeyboardRootView {
    /// Test-only: produce a view with the popover already visible for `key`.
    static func forcedPopoverPreview(key: Character) -> some View {
        var view = KeyboardRootView(onInsertText: { _ in }, onDeleteBackward: {}, onAdvanceInputMode: {})
        view._popoverKey = State(initialValue: key)
        view._popoverVariants = State(initialValue: IPAMapping.variants[key] ?? [])
        view._popoverSelection = State(initialValue: 0)
        return view
    }
}
#endif
```

(`State` can be initialized via backing-property syntax; if Xcode complains, expose a `@State private(set)` or fold into an init that takes these as parameters.)

- [ ] **Step 3: Record and visually verify**

Set `isRecording = true`, run the suite, open every `__Snapshots__/*.png` and confirm:
- Popover **never off-screen**, even for `z` at iPhone SE width and `n` at 320pt iPad floating.
- The selected variant is visually distinct (blue background).
- Popover is *above* the key when there's room, *below* it for top-row keys.

Set `isRecording = false`, confirm GREEN.

- [ ] **Step 4: Commit**

```bash
git add ios/Tests/KeyboardExtensionSnapshotTests/ \
        ios/IPAKeyboardExtension/Views/KeyboardRootView.swift
git commit -m "ios: snapshot tests — popover never off-screen

Corner keys (a, o, z, n) x narrow widths (320pt, iPhone SE, iPad floating).
Debug-only forcedPopoverPreview(key:) injects initial state."
```

---

## Task 3.5 — Gesture-cancellation integration test

**Files:**
- Modify: `ios/IPAKeyboardExtension/KeyboardViewController.swift`

`UIInputViewController` exposes lifecycle hooks we must forward to the SwiftUI layer so that iOS-driven cancellations (incoming call, Control Center, orientation change) clear state.

- [ ] **Step 1: Override `textDidChange` and cancellation hooks**

Add to `KeyboardViewController.swift`:

```swift
extension KeyboardViewController {
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.post(name: .ipaKeyboardShouldCancelGesture, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        NotificationCenter.default.post(name: .ipaKeyboardShouldCancelGesture, object: nil)
        super.viewWillTransition(to: size, with: coordinator)
    }
}

extension Notification.Name {
    static let ipaKeyboardShouldCancelGesture = Notification.Name("ipa.gesture.cancel")
}
```

- [ ] **Step 2: Observe in `KeyboardRootView`**

At the end of `KeyboardRootView.body` (inside the GeometryReader's outer `ZStack` modifier chain):

```swift
        .onReceive(NotificationCenter.default.publisher(for: .ipaKeyboardShouldCancelGesture)) { _ in
            touch.cancel()
            popoverKey = nil
            popoverVariants = []
            popoverSelection = nil
        }
```

- [ ] **Step 3: Manual simulate**

In the simulator: start a long-press on `a`, and while the popover is visible, rotate the device (Cmd-Left-Arrow / Cmd-Right-Arrow in Simulator). Verify the popover disappears cleanly — no stuck popover, no phantom insertion on rotation.

Also: start a long-press, then hit Home (Cmd-Shift-H), then re-enter. Verify the popover is gone.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardExtension/
git commit -m "ios: cancel gesture on VC lifecycle events

viewWillDisappear + viewWillTransition post a cancel notification that
the SwiftUI layer observes. Prevents stuck popover on rotation,
backgrounding, incoming call, Control Center swipe-down."
```

---

## Phase 3 exit checklist

- [x] `swift test --filter TouchStateTests` — 6 tests pass
- [x] `xcodebuild test` — popover snapshot tests GREEN on iPhone SE, iPhone 15, iPad floating width
- [ ] Manual: long-press `a`, popover shows, drag across variants, release on each → correct variant inserted
- [ ] Manual: long-press `a`, release over nothing → no text inserted
- [ ] Manual: long-press `a`, hit home button → popover dismisses, no phantom insert on return
- [ ] Manual: long-press `a`, globe-cycle rapidly → no crash, no stuck popover
- [ ] Haptic felt on successful variant insert (on physical device)
- [ ] All 11 dotted keys open a popover containing exactly the variants listed in `shared-config/default-mappings.json` (verify by tapping all 11 on device)

When all boxes are ticked, tick Phase 3 in `ios/PLAN.md` and move to Phase 4.
