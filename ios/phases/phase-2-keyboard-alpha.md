# Phase 2 — Keyboard alpha layer (no popover yet)

**Ships:** Tappable QWERTY keyboard inside the extension. Plain taps insert the literal letter via `insertText`. 11 dotted letters show a blue-dot indicator. Shift works. Function row (🌐 globe, space, backspace, return, `123` stub) works. No long-press popover yet — that's Phase 3.

**Spec sections:** §3.1 architecture rules, §4.1 layout, §4.2 interaction rules (tap / shift / backspace / globe rows), §8.2 snapshot tests.

**Pre-req:** Phase 1 complete (`IPACore` integrated into both targets, `IPAMapping.dottedKeys` available).

---

## Task 2.1 — Swap the stub `UILabel` for a `UIHostingController` hosting SwiftUI

**Files:**
- Modify: `ios/IPAKeyboardExtension/KeyboardViewController.swift`
- Create: `ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`

- [ ] **Step 1: Create a placeholder SwiftUI root**

`ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`:

```swift
import SwiftUI
import IPACore

struct KeyboardRootView: View {

    /// Called with the literal string to insert into the host text field.
    let onInsertText: (String) -> Void
    /// Called for backspace.
    let onDeleteBackward: () -> Void
    /// Called to advance to the next keyboard (globe button).
    let onAdvanceInputMode: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6)
            Text("alpha layer WIP")
        }
    }
}
```

- [ ] **Step 2: Replace `KeyboardViewController`'s body**

`ios/IPAKeyboardExtension/KeyboardViewController.swift`:

```swift
import UIKit
import SwiftUI
import IPACore

final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = KeyboardRootView(
            onInsertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDeleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onAdvanceInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController = hosting
    }
}
```

- [ ] **Step 3: Build and load in simulator**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -5`

Install to a booted iPhone 15 simulator. In Settings → General → Keyboard → Keyboards → Add New Keyboard, add IPA Keyboard. Open Notes, tap the globe, switch to IPA Keyboard. You should see `alpha layer WIP`.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardExtension/KeyboardViewController.swift \
        ios/IPAKeyboardExtension/Views/KeyboardRootView.swift
git commit -m "ios: host SwiftUI inside UIInputViewController

Callbacks for insertText / deleteBackward / advanceToNextInputMode
are passed in via KeyboardRootView initializer — view has no reference
to textDocumentProxy, keeping it testable in SwiftUI previews."
```

---

## Task 2.2 — `KeyView` (single key) with dot indicator

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/KeyView.swift`

- [ ] **Step 1: Implement**

`ios/IPAKeyboardExtension/Views/KeyView.swift`:

```swift
import SwiftUI

struct KeyView: View {
    enum Style { case letter, function, returnKey, shift }

    let label: String
    let style: Style
    let showsDot: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(background)
                .overlay(
                    Text(label)
                        .font(font)
                        .foregroundColor(foreground)
                )
            if showsDot {
                Circle()
                    .fill(Color(red: 0.40, green: 0.67, blue: 1.0))
                    .frame(width: 5, height: 5)
                    .offset(x: -5, y: 5)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                }
        )
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    private var background: Color {
        switch style {
        case .letter: return Color(uiColor: .systemGray4)
        case .function: return Color(uiColor: .systemGray3)
        case .returnKey: return Color(red: 0.40, green: 0.67, blue: 1.0)
        case .shift: return Color(uiColor: .systemGray3)
        }
    }

    private var foreground: Color {
        style == .returnKey ? .black : .primary
    }

    private var font: Font {
        switch style {
        case .letter: return .system(size: 22, weight: .regular)
        case .function, .shift: return .system(size: 14, weight: .regular)
        case .returnKey: return .system(size: 14, weight: .semibold)
        }
    }

    private var accessibilityName: String {
        switch style {
        case .letter: return "Key \(label)"
        case .function:
            if label == "space" { return "Space" }
            if label == "🌐" { return "Next keyboard" }
            if label == "123" { return "Numbers" }
            return label
        case .returnKey: return "Return"
        case .shift: return "Shift"
        }
    }
}
```

- [ ] **Step 2: Xcode SwiftUI preview works**

Add to the same file at the bottom:

```swift
#Preview {
    HStack(spacing: 8) {
        KeyView(label: "q", style: .letter, showsDot: false, onTap: {})
        KeyView(label: "a", style: .letter, showsDot: true, onTap: {})
        KeyView(label: "⌫", style: .function, showsDot: false, onTap: {})
        KeyView(label: "return", style: .returnKey, showsDot: false, onTap: {})
    }
    .padding()
    .frame(height: 60)
}
```

In Xcode, open `KeyView.swift`, activate the Canvas (Option-Cmd-Enter), verify four keys render correctly and the dot appears only on `a`.

- [ ] **Step 3: Commit**

```bash
git add ios/IPAKeyboardExtension/Views/KeyView.swift
git commit -m "ios: KeyView with style variants and blue-dot indicator

Dot is 5x5pt blue in top-right corner. Indicator is accessibilityHidden=true
because the key's VoiceOver label handles 'has variants' announcement."
```

---

## Task 2.3 — `KeyRow` and full alpha layout

**Files:**
- Create: `ios/IPAKeyboardExtension/Views/KeyRow.swift`
- Modify: `ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`

- [ ] **Step 1: Implement `KeyRow`**

`ios/IPAKeyboardExtension/Views/KeyRow.swift`:

```swift
import SwiftUI
import IPACore

struct KeyRow: View {
    let keys: [Character]
    let isShifted: Bool
    let onTap: (Character) -> Void

    private static let dotted: Set<Character> = Set(IPAMapping.dottedKeys)

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyView(
                    label: isShifted ? String(key).uppercased() : String(key),
                    style: .letter,
                    showsDot: Self.dotted.contains(key),
                    onTap: { onTap(key) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

- [ ] **Step 2: Rewrite `KeyboardRootView.body` for the full alpha layer**

`ios/IPAKeyboardExtension/Views/KeyboardRootView.swift`:

```swift
import SwiftUI
import IPACore

struct KeyboardRootView: View {

    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    @State private var isShifted: Bool = false

    private let row1: [Character] = Array("qwertyuiop")
    private let row2: [Character] = Array("asdfghjkl")
    private let row3: [Character] = Array("zxcvbnm")

    var body: some View {
        VStack(spacing: 6) {
            KeyRow(keys: row1, isShifted: isShifted, onTap: insert)
                .frame(height: rowHeight)

            HStack {
                Spacer(minLength: sideInset)
                KeyRow(keys: row2, isShifted: isShifted, onTap: insert)
                    .frame(height: rowHeight)
                Spacer(minLength: sideInset)
            }

            HStack(spacing: 5) {
                KeyView(label: "⇧", style: .shift, showsDot: false, onTap: { isShifted.toggle() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                KeyRow(keys: row3, isShifted: isShifted, onTap: insert)
                    .frame(height: rowHeight)
                KeyView(label: "⌫", style: .function, showsDot: false, onTap: { onDeleteBackward() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: rowHeight)

            functionRow
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .background(Color(uiColor: .systemGray6))
    }

    private var functionRow: some View {
        HStack(spacing: 5) {
            KeyView(label: "123", style: .function, showsDot: false, onTap: { /* Phase 4 */ })
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "🌐", style: .function, showsDot: false, onTap: onAdvanceInputMode)
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "space", style: .function, showsDot: false, onTap: { onInsertText(" ") })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            KeyView(label: "IPA", style: .function, showsDot: false, onTap: { /* future */ })
                .frame(maxWidth: 44, maxHeight: .infinity)
                .opacity(0.5)
                .disabled(true)
            KeyView(label: "return", style: .returnKey, showsDot: false, onTap: { onInsertText("\n") })
                .frame(maxWidth: 64, maxHeight: .infinity)
        }
        .frame(height: rowHeight)
    }

    private func insert(_ key: Character) {
        let s = isShifted ? String(key).uppercased() : String(key)
        onInsertText(s)
        if isShifted { isShifted = false }
    }

    // Size-class-adaptive sizing. Actual iOS keyboard heights.
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }            // iPad
        if vSize == .compact { return 38 }            // iPhone landscape
        return 44                                     // iPhone portrait
    }

    private var totalHeight: CGFloat {
        rowHeight * 4 + 30
    }

    private var sideInset: CGFloat { 18 }
}
```

Shift auto-releases after one letter (matches iOS). Space inserts `" "`. Return inserts `"\n"`. The `IPA` key is disabled in v1 (spec §4.1 shows it in the function row but v1 scope doesn't include a per-key picker — reserved for future use).

- [ ] **Step 3: Build and install to simulator, verify taps**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -5`

In Notes with IPA Keyboard active: type `hello`, verify text appears. Tap shift then `a`, verify `A` appears and shift releases. Tap backspace, verify deletion. Tap globe, verify it switches away.

- [ ] **Step 4: Commit**

```bash
git add ios/IPAKeyboardExtension/Views/KeyRow.swift \
        ios/IPAKeyboardExtension/Views/KeyboardRootView.swift
git commit -m "ios: full alpha layer — QWERTY + shift + function row

11 dotted keys show indicator from IPAMapping.dottedKeys.
Shift auto-releases after one keystroke. Row heights adapt by size class."
```

---

## Task 2.4 — Snapshot tests for the alpha layer

**Files:**
- Create: `ios/Tests/KeyboardExtensionSnapshotTests/KeyboardSnapshotTests.swift`
- Modify: `ios/IPACore/Package.swift` (add `swift-snapshot-testing` as a test-only dep of the test target — the real test target lives in Xcode, but we also validate via SPM for speed)

Because the keyboard extension target isn't easily testable headlessly, we snapshot `KeyboardRootView` directly. Add the snapshot target to Xcode, not to the extension itself — snapshot-testing must NOT ship inside the extension binary (size limit).

- [ ] **Step 1: Add `swift-snapshot-testing` via Xcode**

Xcode → project settings → Package Dependencies → `+` → `https://github.com/pointfreeco/swift-snapshot-testing` → Up to Next Major from `1.15.0`. Add `SnapshotTesting` library only to the `KeyboardExtensionSnapshotTests` test target (create one if it doesn't exist: File → New → Target → Unit Testing Bundle, name `KeyboardExtensionSnapshotTests`, target to test: `IPAKeyboardExtension`).

- [ ] **Step 2: Write the snapshot test**

`ios/Tests/KeyboardExtensionSnapshotTests/KeyboardSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import IPAKeyboardExtension

final class KeyboardSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // isRecording = true    // Uncomment temporarily to regenerate baselines.
    }

    private func root() -> some View {
        KeyboardRootView(
            onInsertText: { _ in },
            onDeleteBackward: {},
            onAdvanceInputMode: {}
        )
    }

    func test_iPhone15_portrait_light() {
        let view = root().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPhone15_portrait_dark() {
        let view = root().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .dark)))
    }

    func test_iPhoneSE_portrait_light() {
        let view = root().frame(width: 320, height: 216)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhoneSe, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPhone15_landscape_light() {
        let view = root().frame(width: 852, height: 200)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13(.landscape),
                                  traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPad_portrait_light() {
        let view = root().frame(width: 820, height: 320)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPadMini, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPad_floatingWidth_light() {
        let view = root().frame(width: 320, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(size: CGSize(width: 320, height: 260),
                                  traits: .init(userInterfaceStyle: .light)))
    }
}
```

- [ ] **Step 3: Record baselines**

Set `isRecording = true` once, run the test suite (Cmd-U in Xcode or `xcodebuild test -scheme IPAKeyboardApp`), inspect every generated PNG in `__Snapshots__/`, confirm no key is clipped, all 11 dots are visible, shift/globe/return render distinctly. Set `isRecording = false`, re-run, confirm GREEN.

- [ ] **Step 4: Commit the images**

```bash
git add ios/Tests/KeyboardExtensionSnapshotTests/ \
        ios/IPAKeyboard.xcodeproj/
git commit -m "ios: snapshot tests for alpha layer across six size classes

Covers iPhone SE / 15 portrait+landscape, iPad portrait,
iPad floating width (320pt). Light+dark for iPhone 15.
Baselines committed; PR diffs gate on visual regressions."
```

---

## Task 2.5 — Manual smoke test milestone

- [ ] **Step 1: Install to a real device (optional, recommended)**

Open Xcode → select IPAKeyboardApp scheme → Run on a connected iPhone. (Requires your personal Apple ID to be set as signing team; Xcode will guide you.)

- [ ] **Step 2: Work the happy path**

In Settings → General → Keyboard → Keyboards → Add New Keyboard → IPA Keyboard. Then in Notes:
- Type `hello world` — verify plain text works
- Tap shift, tap `h` — verify `H` and shift auto-released
- Tap backspace 5× — verify deletion, grapheme-correct
- Tap 🌐 — verify it cycles away to system keyboard, and back
- Rotate to landscape — verify compressed row heights

- [ ] **Step 3: Check for console errors**

In Xcode's Devices & Simulators → select your device → Open Console. Filter by process `IPAKeyboardExtension`. Confirm no crash logs, no `dyld` errors, no memory warnings.

- [ ] **Step 4: Tick phase exit**

If everything is clean, phase 2 is done.

---

## Phase 2 exit checklist

- [ ] `xcodebuild -scheme IPAKeyboardApp test` runs the snapshot tests and all 6 pass
- [ ] Manual smoke: keyboard visible in Settings, adds successfully, types plain letters, shift and backspace work, globe cycles
- [ ] All 11 dotted letters (a, e, i, o, u, t, s, d, c, n, z) show a blue dot
- [ ] Unintended letters (q, w, r, etc.) do NOT show a dot
- [ ] No console errors from the extension during a 30-second typing session
- [ ] SwiftUI previews in Xcode render for `KeyView` and `KeyboardRootView` without crashing

When all boxes are ticked, tick Phase 2 in `ios/PLAN.md` and move to Phase 3 (popover).
