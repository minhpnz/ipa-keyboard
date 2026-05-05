# Phase 5 — Container app: Setup tab

**Ships:** `RootTabView` with three tabs (Setup / Reference / About — only Setup functional this phase). `SetupView` with the sticky-CTA layout from spec §5.2 (numbered circles, "Try it here" field, "I've done this" collapse, troubleshooting sheet link). `TroubleshootingSheet`. State persisted in the container app's own UserDefaults (`hasConfirmedSetup`, `defaultTab`, `sawIpaCharacterInTestField`).

**Spec sections:** §5.1 three tabs, §5.2 Setup tab rules, §5.2.1 troubleshooting sheet, §6.1 state model, §7.2 error handling.

**Pre-req:** Phases 1–4 complete. `SymbolDetector.containsIPA` available in `IPACore`.

---

## Task 5.1 — `AppState` (ObservableObject) for container app

**Files:**
- Create: `ios/IPAKeyboardApp/AppState.swift`
- Create: `ios/Tests/IPAKeyboardAppUITests/AppStateTests.swift` (actually unit, not UI — use the `IPAKeyboardAppTests` target Xcode created)

- [x] **Step 1: Failing tests first**

`ios/IPAKeyboardAppTests/AppStateTests.swift` (use the default unit-test target Xcode creates with the app):

```swift
import XCTest
@testable import IPAKeyboardApp

final class AppStateTests: XCTestCase {
    private let testSuite = "ipa.tests.\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: testSuite)!
        defaults.removePersistentDomain(forName: testSuite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: testSuite)
        super.tearDown()
    }

    func test_defaultsOnFirstLaunch() {
        let s = AppState(defaults: defaults)
        XCTAssertFalse(s.hasConfirmedSetup)
        XCTAssertEqual(s.defaultTab, .setup)
        XCTAssertFalse(s.sawIpaCharacterInTestField)
    }

    func test_confirmingSetupFlipsDefaultTab() {
        let s = AppState(defaults: defaults)
        s.confirmSetup()
        XCTAssertTrue(s.hasConfirmedSetup)
        XCTAssertEqual(s.defaultTab, .reference)
    }

    func test_confirmationPersistsAcrossInstances() {
        let first = AppState(defaults: defaults)
        first.confirmSetup()
        let second = AppState(defaults: defaults)
        XCTAssertTrue(second.hasConfirmedSetup)
        XCTAssertEqual(second.defaultTab, .reference)
    }

    func test_sawIpaOnceThenStaysTrue() {
        let s = AppState(defaults: defaults)
        s.noteTextFieldChanged("æ is nice")
        XCTAssertTrue(s.sawIpaCharacterInTestField)
        s.noteTextFieldChanged("hello")    // irrelevant content
        XCTAssertTrue(s.sawIpaCharacterInTestField, "should not un-flip")
    }

    func test_sawIpaStaysFalseForPlainText() {
        let s = AppState(defaults: defaults)
        s.noteTextFieldChanged("hello world")
        XCTAssertFalse(s.sawIpaCharacterInTestField)
    }
}
```

- [x] **Step 2: Implement**

`ios/IPAKeyboardApp/AppState.swift`:

```swift
import Foundation
import Combine
import IPACore

enum Tab: String {
    case setup, reference, about
}

final class AppState: ObservableObject {
    @Published private(set) var hasConfirmedSetup: Bool
    @Published private(set) var sawIpaCharacterInTestField: Bool
    @Published var testFieldText: String = ""    // bound by SetupView

    private let defaults: UserDefaults

    enum Keys {
        static let hasConfirmedSetup = "ipa.hasConfirmedSetup"
        static let sawIpaCharacterInTestField = "ipa.sawIpaCharacterInTestField"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConfirmedSetup = defaults.bool(forKey: Keys.hasConfirmedSetup)
        self.sawIpaCharacterInTestField = defaults.bool(forKey: Keys.sawIpaCharacterInTestField)
    }

    var defaultTab: Tab {
        hasConfirmedSetup ? .reference : .setup
    }

    func confirmSetup() {
        hasConfirmedSetup = true
        defaults.set(true, forKey: Keys.hasConfirmedSetup)
    }

    func showStepsAgain() {
        hasConfirmedSetup = false
        defaults.set(false, forKey: Keys.hasConfirmedSetup)
    }

    func noteTextFieldChanged(_ text: String) {
        testFieldText = text
        if !sawIpaCharacterInTestField && SymbolDetector.containsIPA(text) {
            sawIpaCharacterInTestField = true
            defaults.set(true, forKey: Keys.sawIpaCharacterInTestField)
        }
    }
}
```

- [x] **Step 3: Run tests**

Run: `xcodebuild test -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IPAKeyboardAppTests/AppStateTests 2>&1 | tail -10`
Expected: 5 tests pass.

- [x] **Step 4: Commit**

```bash
git add ios/IPAKeyboardApp/AppState.swift ios/IPAKeyboardAppTests/AppStateTests.swift
git commit -m "ios: AppState ObservableObject with persisted flags

Uses app's own UserDefaults (no App Group). Tests hit a per-test suite
to stay hermetic. sawIpaCharacterInTestField only flips true, never back."
```

---

## Task 5.2 — `RootTabView` + stub other tabs

**Files:**
- Create: `ios/IPAKeyboardApp/Views/RootTabView.swift`
- Create: `ios/IPAKeyboardApp/Views/SetupView.swift` (stub for this task)
- Create: `ios/IPAKeyboardApp/Views/ReferenceView.swift` (stub — fleshed out in Phase 6)
- Create: `ios/IPAKeyboardApp/Views/AboutView.swift` (stub — fleshed out in Phase 6)
- Modify: `ios/IPAKeyboardApp/IPAKeyboardAppApp.swift`

- [x] **Step 1: Write `RootTabView`**

```swift
import SwiftUI

struct RootTabView: View {
    @StateObject private var state = AppState()
    @State private var selection: Tab = .setup

    var body: some View {
        TabView(selection: $selection) {
            SetupView()
                .environmentObject(state)
                .tabItem { Label("Setup", systemImage: "checklist") }
                .tag(Tab.setup)

            ReferenceView()
                .environmentObject(state)
                .tabItem { Label("Reference", systemImage: "text.book.closed") }
                .tag(Tab.reference)

            AboutView()
                .environmentObject(state)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .onAppear { selection = state.defaultTab }
    }
}

#Preview { RootTabView() }
```

- [x] **Step 2: Stub the other two views**

`ReferenceView.swift`:

```swift
import SwiftUI

struct ReferenceView: View {
    var body: some View { Text("Reference (WIP)") }
}
```

`AboutView.swift`:

```swift
import SwiftUI

struct AboutView: View {
    var body: some View { Text("About (WIP)") }
}
```

`SetupView.swift`:

```swift
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var state: AppState
    var body: some View { Text("Setup (WIP)") }
}
```

- [x] **Step 3: Wire `RootTabView` as the app root**

`IPAKeyboardAppApp.swift`:

```swift
import SwiftUI

@main
struct IPAKeyboardAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
```

- [x] **Step 4: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator build | tail -5`
Expected: success.

- [x] **Step 5: Commit**

```bash
git add ios/IPAKeyboardApp/
git commit -m "ios: container app RootTabView with three tab stubs

Default tab driven by AppState.defaultTab (.setup on first launch,
.reference after hasConfirmedSetup is true)."
```

---

## Task 5.3 — `SetupView` — numbered circles + sticky CTA + try-it field

**Files:**
- Modify: `ios/IPAKeyboardApp/Views/SetupView.swift`

- [x] **Step 1: Implement**

```swift
import SwiftUI
import UIKit
import IPACore

struct SetupView: View {
    @EnvironmentObject var state: AppState
    @State private var showingTroubleshooting = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !state.hasConfirmedSetup {
                            header
                            instructions
                            Divider()
                            tryItField
                            iveDoneThisButton
                        } else {
                            collapsedBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 180) // room for sticky CTA
                }
                stickyCTA
            }
        }
        .sheet(isPresented: $showingTroubleshooting) {
            TroubleshootingSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STEP 1 OF 1 · ACTIVATE KEYBOARD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .tracking(0.8)
            Text("Enable IPA Keyboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Follow these steps in the Settings app:")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionRow(n: 1, text: "Open Settings")
            instructionRow(n: 2, text: "Go to General → Keyboard → Keyboards")
            instructionRow(n: 3, text: "Tap \"Add New Keyboard…\" → IPA Keyboard")
        }
    }

    private func instructionRow(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .accessibilityLabel("Step \(n). \(text)")
            Spacer()
        }
    }

    private var tryItField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it here")
                .font(.headline)
            TextField("", text: Binding(
                get: { state.testFieldText },
                set: { state.noteTextFieldChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .serif))
            .autocorrectionDisabled(true)
            .accessibilityLabel("Test keyboard input")

            Text(helperText)
                .font(.footnote)
                .foregroundColor(helperColor)
                .animation(.easeIn(duration: 0.2), value: state.sawIpaCharacterInTestField)
        }
    }

    private var helperText: String {
        state.sawIpaCharacterInTestField
            ? "Looks like it’s working ✓"
            : "Tap the globe 🌐 to switch to IPA Keyboard"
    }

    private var helperColor: Color {
        state.sawIpaCharacterInTestField ? .green : .secondary
    }

    private var iveDoneThisButton: some View {
        Button("I’ve done this") {
            state.confirmSetup()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var collapsedBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 28))
                Text("Setup complete — keyboard ready to use")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Button("Show steps again") { state.showStepsAgain() }
                .buttonStyle(.bordered)
        }
    }

    private var stickyCTA: some View {
        VStack(spacing: 10) {
            Divider()
            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)

            Button("Keyboard not appearing in Settings? →") {
                showingTroubleshooting = true
            }
            .font(.footnote)
            .padding(.bottom, 12)
        }
        .background(.thinMaterial)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok {
                // Spec §7.2: alert fallback if openSettings fails.
                let alert = UIAlertController(
                    title: "Couldn’t open Settings",
                    message: "Please open Settings manually and go to General → Keyboard → Keyboards.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                if let root = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    root.present(alert, animated: true)
                }
            }
        }
    }
}
```

- [x] **Step 2: Build**

Run: `xcodebuild -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -sdk iphonesimulator build | tail -5`
Expected: success. If the `keyWindow` API complains (iOS 16 deprecation), read the keyWindow via `UIApplication.shared.connectedScenes.compactMap(...)` — the block above already uses the recommended form.

- [x] **Step 3: Visual check in simulator**

Launch the container app. Confirm:
- "STEP 1 OF 1" eyebrow renders in accent color
- Three numbered circles (1, 2, 3) each with a step
- Divider, then "Try it here" field with helper text
- "I've done this" secondary button
- Sticky at bottom: blue "Open Settings" button + small "Keyboard not appearing?" link
- Tapping "Open Settings" deep-links to the Settings app
- Tapping the troubleshooting link opens… nothing yet (sheet in next task)
- Tapping "I've done this" collapses the whole layout to "Setup complete" banner

- [x] **Step 4: Commit**

```bash
git add ios/IPAKeyboardApp/Views/SetupView.swift
git commit -m "ios: SetupView — numbered-circle instructions + sticky Open Settings CTA

'STEP 1 OF 1' eyebrow frames this as a one-time milestone.
Try-it field binds to AppState; helper text flips to green when IPA detected.
I've done this collapses the screen; Show steps again re-expands."
```

---

## Task 5.4 — `TroubleshootingSheet`

**Files:**
- Create: `ios/IPAKeyboardApp/Views/TroubleshootingSheet.swift`

- [x] **Step 1: Implement**

```swift
import SwiftUI

struct TroubleshootingSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Keyboard not appearing in Settings?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)

                    bullet("Make sure you’re on iOS 17 or later. IPA Keyboard requires iOS 17+ — check Settings → General → About.")
                    bullet("Fully quit the Settings app (swipe up from the bottom and flick Settings away), then reopen it. iOS sometimes caches the keyboards list.")
                    bullet("Restart your iPhone. After a fresh install, iOS can take a moment to register the new keyboard extension.")
                    bullet("Still not working? Delete IPA Keyboard, reinstall from the App Store, and try again.")

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•").font(.body)
            Text(text).font(.body).multilineTextAlignment(.leading)
        }
    }
}

#Preview { TroubleshootingSheet() }
```

Note: The copy mentions iOS 17 per spec §5.2.1. `MinimumOSVersion` in `Info.plist` is 16.0 per spec §9.3 — the iOS 17 copy is defensive (iOS 16 is a long-tail device; the sheet focuses help on the common case).

- [x] **Step 2: Verify**

Tap the troubleshooting link in `SetupView`. Sheet slides up. All four bullets render. Close button dismisses.

- [x] **Step 3: Commit**

```bash
git add ios/IPAKeyboardApp/Views/TroubleshootingSheet.swift
git commit -m "ios: TroubleshootingSheet with four static bullets

No network, no support email, no remote URLs.
Content matches spec §5.2.1 verbatim."
```

---

## Task 5.5 — UI tests for Setup flow

**Files:**
- Create: `ios/IPAKeyboardAppUITests/SetupTabUITests.swift`

- [x] **Step 1: Implement**

```swift
import XCTest

final class SetupTabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Force a clean AppState by passing a launch arg the app respects.
        app.launchArguments += ["-AppleLanguages", "(en)", "-ResetSetupForUITests", "YES"]
        app.launch()
        return app
    }

    func test_firstLaunchShowsSetupTabWithInstructionNumbersAndStickyCTA() {
        let app = launchFreshApp()
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Step 1. Open Settings"].exists)
        XCTAssertTrue(app.staticTexts["Step 2. Go to General → Keyboard → Keyboards"].exists)
        XCTAssertTrue(app.staticTexts["Step 3. Tap \"Add New Keyboard…\" → IPA Keyboard"].exists)
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)
    }

    func test_numberedCircleTapIsNoOp() {
        let app = launchFreshApp()
        // Numbered circles are decorative (accessibilityHidden); tapping their text
        // area must not mutate any state. We verify by tapping and confirming
        // "I've done this" still flips state correctly afterward.
        let step1 = app.staticTexts["Step 1. Open Settings"]
        step1.tap()
        step1.tap()
        XCTAssertTrue(app.buttons["I’ve done this"].isHittable)
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].exists, "Still on Setup")
    }

    func test_troubleshootingLinkOpensAndClosesSheet() {
        let app = launchFreshApp()
        app.buttons["Keyboard not appearing in Settings? →"].tap()
        XCTAssertTrue(app.staticTexts["Keyboard not appearing in Settings?"].waitForExistence(timeout: 2))
        app.buttons["Close"].tap()
        XCTAssertFalse(app.staticTexts["Keyboard not appearing in Settings?"].exists)
    }

    func test_iveDoneThisCollapsesAndPersists() {
        let app = launchFreshApp()
        app.buttons["I’ve done this"].tap()
        XCTAssertTrue(app.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Show steps again"].isHittable)
        // Open Settings CTA must remain visible even after collapse.
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)

        // Relaunch (without reset) — state must persist.
        app.terminate()
        let app2 = XCUIApplication()
        app2.launch()
        XCTAssertTrue(app2.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 2))
    }

    func test_showStepsAgainReExpands() {
        let app = launchFreshApp()
        app.buttons["I’ve done this"].tap()
        XCTAssertTrue(app.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 2))
        app.buttons["Show steps again"].tap()
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].waitForExistence(timeout: 2))
    }
}
```

- [x] **Step 2: Wire the reset launch argument in `IPAKeyboardAppApp`**

Add to `IPAKeyboardAppApp.swift`:

```swift
@main
struct IPAKeyboardAppApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ResetSetupForUITests") {
            let d = UserDefaults.standard
            d.removeObject(forKey: AppState.Keys.hasConfirmedSetup)
            d.removeObject(forKey: AppState.Keys.sawIpaCharacterInTestField)
        }
    }
    var body: some Scene {
        WindowGroup { RootTabView() }
    }
}
```

- [x] **Step 3: Run UI tests**

Run: `xcodebuild test -project ios/IPAKeyboard.xcodeproj -scheme IPAKeyboardApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IPAKeyboardAppUITests/SetupTabUITests 2>&1 | tail -20`
Expected: 5 tests pass. First run may be slow as simulator boots.

- [x] **Step 4: Commit**

```bash
git add ios/IPAKeyboardAppUITests/SetupTabUITests.swift \
        ios/IPAKeyboardApp/IPAKeyboardAppApp.swift
git commit -m "ios: UI tests for Setup flow

Numbered circles non-interactive, I've done this persists, troubleshooting
sheet round-trips, Show steps again re-expands, Open Settings CTA remains
visible post-collapse."
```

---

## Phase 5 exit checklist

- [x] `AppStateTests` — 5/5 pass
- [x] `SetupTabUITests` — 5/5 pass
- [ ] Manual: clean install → Setup tab is default → tap "Open Settings" → lands on app's Settings page in Settings.app (iOS deep-link fallback acceptable)
- [x] Manual: in "Try it here" field, paste `kæt` → helper text flips to green "Looks like it’s working ✓"
- [x] Manual: type plain `hello` in field → helper text does NOT flip to green
- [x] Manual: sawIpaCharacterInTestField never un-flips after it went true, even after killing and relaunching the app
- [x] Manual: troubleshooting sheet reads cleanly, scrollable on iPhone SE, close dismisses
- [x] VoiceOver: each numbered step reads as "Step 1. Open Settings" (etc.)
- [x] No references to App Group in `SetupView` or `AppState` (spot-check: `grep -R 'group\.' ios/IPAKeyboardApp/` returns nothing)

When all boxes are ticked, tick Phase 5 in `ios/PLAN.md` and move to Phase 6.
