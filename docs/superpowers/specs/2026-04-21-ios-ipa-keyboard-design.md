# iOS IPA Keyboard — Design Spec

- **Date:** 2026-04-21
- **Status:** Draft, pending final user review
- **Author:** Brainstorm session (minh.phan81299@gmail.com + Claude)
- **Scope:** iOS (iPhone + iPad) — keyboard extension + container app, distributed via App Store
- **Out of scope (this spec):** macOS App Store sibling (deferred to a follow-up project), Windows, any rewrite of the existing `ime-core/` or `companion-app/`

---

## 1. Context

The `ipa-keyboard` project already ships:

- A macOS system IME (`ime-core/macos/`, Rust + InputMethodKit, CGEvent taps) distributed via Developer ID + notarization
- A Tauri/React companion app (`companion-app/`) — also submittable to the Mac App Store, flow documented in `docs/MAC-APP-STORE-GUIDE.md`
- A Windows TSF IME
- A single source of truth for key mappings: `shared-config/default-mappings.json`

This spec adds a **third platform: iOS**, delivered as an App Store app. The existing codebases are not modified; iOS is a new Swift codebase that shares only the mapping JSON via build-time codegen.

**Why now:** User wants a mobile IPA keyboard for typing into any iOS app (Messages, Notes, Safari, etc.). iOS's third-party keyboard model fits the project's "add new keyboard" mental model cleanly. The current desktop UX does not translate directly — iOS has no Ctrl key, no cycling convention — but iOS's native long-press popover (as used for accented characters) maps naturally to the "variants behind each letter" concept.

---

## 2. Scope decisions (locked during brainstorm)

| Decision | Value | Reason |
|---|---|---|
| Platform scope | **iOS only.** macOS App Store sibling is a future follow-up project. | Existing macOS IME uses CGEvent taps (documented incompatible with App Sandbox in `docs/DISTRIBUTION.md`). Rewriting for App Store would sacrifice system-wide interception. Keeping them on separate tracks. |
| Symbol set | **Exactly the 18 IPA variants in `shared-config/default-mappings.json`** — 11 base letters (`a e i o u t s d c n z`) with their IPA variants (`a`→3, `e/i/o/u/t`→2 each, `s/d/c/n/z`→1 each). No new symbols in v1. | User requested no expansion. |
| Interaction model | **QWERTY keyboard, long-press dotted letters for IPA variants** (iOS-native popover pattern, identical to system é/è popover, but showing IPA). Tap = literal letter. | Matches iOS idiom. Zero new gestures for users. Max 3 variants per letter comfortably fits the popover. |
| Container app scope (Tier B) | **Onboarding + IPA symbol reference.** No document editor, no favorites, no search. | Tier A was too bare (orphan home-screen icon); Tier C (full editor) doubles the surface area with no v1 necessity. |
| Permissions | **No Full Access in v1.** Empty entitlements in both targets. | Aligns with `CLAUDE.md`'s offline-first / no-telemetry policy. Reviews faster. "Does not require Full Access" is a genuine user-trust signal. Door stays open for optional Full Access in v1.1. |
| Devices | **iPhone + iPad via adaptive SwiftUI layout** (size classes). No hand-crafted iPad-only layout. | iPhone-only leaves a visible rough edge on iPad users. Hand-crafted iPad polish is premature for v1. |
| iOS minimum | iOS 16.0+ | Covers >95% of active devices in 2026; grants us modern SwiftUI APIs. |

---

## 3. Architecture

```
ipa-keyboard/                     (existing repo, unchanged at root)
├── shared-config/
│   └── default-mappings.json     ← single source of truth
├── ime-core/                     (existing macOS daemon — unchanged)
├── companion-app/                (existing Tauri app — unchanged)
└── ios/                          ← NEW
    ├── IPAKeyboard.xcodeproj
    ├── IPAKeyboardApp/           (container app target)
    │   ├── IPAKeyboardAppApp.swift
    │   ├── Views/
    │   │   ├── RootTabView.swift
    │   │   ├── ReferenceView.swift
    │   │   ├── SetupView.swift
    │   │   └── AboutView.swift
    │   ├── Assets.xcassets
    │   ├── PrivacyInfo.xcprivacy
    │   └── Info.plist
    ├── IPAKeyboardExtension/     (keyboard extension target)
    │   ├── KeyboardViewController.swift   (UIInputViewController subclass)
    │   ├── Views/
    │   │   ├── KeyboardRootView.swift     (hosted in UIHostingController)
    │   │   ├── KeyRow.swift
    │   │   ├── KeyView.swift
    │   │   ├── VariantPopover.swift
    │   │   └── CoachMarkBanner.swift
    │   ├── Services/
    │   │   ├── HapticsService.swift
    │   │   └── InputClickService.swift
    │   ├── Assets.xcassets
    │   ├── PrivacyInfo.xcprivacy
    │   └── Info.plist
    ├── IPACore/                  (local Swift Package, shared by both targets)
    │   ├── Package.swift
    │   └── Sources/IPACore/
    │       ├── IPAMapping.swift             (GENERATED — committed)
    │       ├── SymbolReferenceData.swift    (GENERATED — committed)
    │       ├── LayoutEngine.swift
    │       ├── LocalizedSymbolNames.swift
    │       └── SymbolDetector.swift
    ├── Scripts/
    │   ├── generate-ipa-mapping.sh    (reads ../shared-config/*.json → writes IPACore/*.swift)
    │   ├── preflight.sh               (CI guard: codegen freshness, forbidden APIs, size delta)
    │   ├── update-baseline.sh         (intentional bump of Scripts/baseline-sizes.json)
    │   └── baseline-sizes.json        (committed; tracked extension binary size baseline)
    └── Tests/
        ├── IPACoreTests/
        ├── KeyboardExtensionSnapshotTests/
        └── IPAKeyboardAppUITests/
```

### 3.1 Key architectural rules

- **Two iOS targets** (container app + keyboard extension) — the only way iOS allows keyboard extensions to ship.
- **Shared code via a local Swift Package** (`IPACore`), not a framework. Simpler consumption, tree-shaking per target, no dynamic-linking surprises at App Store review.
- **Generated files are committed to git**, not rebuilt on every CI run. Regenerate only when `shared-config/` changes. Generated files carry a machine-readable header including the source file's hash; preflight validates the hash matches to catch drift.
- **UI framework:** SwiftUI, hosted inside a `UIInputViewController` via `UIHostingController`. iOS 16+ makes this reliable.
- **No App Group, no shared UserDefaults, no Full Access.** Container and extension live in fully isolated state universes. See §5.
- **No network anywhere.** No network entitlement; CI grep for `URLSession|NWConnection|\.network` fails the build if any appear.

---

## 4. Keyboard extension — the core feature

### 4.1 Layout

Standard QWERTY, 3 letter rows + a function row. 11 letters carry a small blue dot indicator in the upper-right corner to signal "has IPA variants":

```
Row 1:   q   w   e•  r   t•  y   u•  i•  o•  p          ← "•" marks letters with IPA variants
Row 2:   a•  s•  d•  f   g   h   j   k   l
Row 3:  ⇧    z•  x   c•  v   b   n•  m   ⌫
Func:  123   🌐            space             return
```
(The "•" is just ASCII notation for the schematic; in the actual UI it's a small blue dot in the top-right corner of the affected keys, not a rendered character.)

Key sizes match the native keyboard at each size class. Row heights:
- iPhone portrait: standard (~54pt keys, ~260pt total input-view height)
- iPhone landscape: compressed (~38pt keys, ~200pt total)
- iPad portrait: wider (~70pt keys, ~320pt total)
- iPad landscape: widest (~80pt keys, ~300pt total)

### 4.2 Interaction rules

| Gesture | Behavior |
|---|---|
| Tap any letter (dotted or not) | Insert that literal letter. Dotted letters still insert the base letter on plain tap. |
| Long-press a dotted letter (≥ 500ms) | Show `VariantPopover` above the key, listing variants in `default-mappings.json` array order. |
| Drag onto a popover variant | Highlight it. |
| Release while a variant is highlighted | `textDocumentProxy.insertText(variant)` · trigger haptic · dismiss popover. |
| Release with no variant highlighted | Cancel. Nothing inserted. |
| Long-press a non-dotted letter | Nothing (match stock-keyboard behavior). |
| Shift | Capitalizes plain letters. Popover variants are case-fixed; shift state is ignored during a popover. |
| 🌐 globe | Standard iOS keyboard switcher. |
| Backspace | `textDocumentProxy.deleteBackward()` — iOS handles grapheme clusters (e.g., `dʒ`, `ɑː`) correctly. We do NOT implement our own codepoint math. |
| 123 / #+= / ABC | Standard iOS numbers/symbols layer (two sub-pages). No IPA on these layers. |

### 4.3 Timing constants (`IPACore/LayoutEngine.swift`)

```swift
public enum LayoutEngine {
    public static let popoverDelay: TimeInterval = 0.5         // matches iOS system feel
    public static let clipboardDebounceInterval: TimeInterval = 0.3
}
```

All tests reference these constants; no literals.

### 4.4 Gesture correctness — token-based cancellation

Every touch gets a fresh UUID token. The long-press timer captures the token and validates it is still the active one before rendering a popover:

```swift
private var activeTouch: (key: Character, token: UUID)? = nil

func touchBegan(key: Character) {
    let token = UUID()
    activeTouch = (key, token)
    DispatchQueue.main.asyncAfter(deadline: .now() + LayoutEngine.popoverDelay) { [weak self] in
        guard let self, self.activeTouch?.token == token else { return }
        self.showPopover(for: key)
    }
}

func touchesCancelled() {
    activeTouch = nil
    hidePopover()
}
```

The token prevents a late timer callback from showing a popover for a gesture that was cancelled — or worse, for a gesture that was ended+restarted on a different key in between. Correct under all interleavings.

### 4.5 Popover geometry

`VariantPopover` is edge-aware:
- Mirrors to the opposite side of the key if the default position would clip the screen
- Falls back to a horizontally scrollable container if even the mirrored position doesn't fit
- **Never renders partially off-screen.** Asserted by snapshot tests across all size classes including iPad floating (~320pt) and split-keyboard modes.

### 4.6 Coach mark (bridge via instruction)

On the first **3 activations** of the keyboard, a translucent pill fades in above the top letter row for ~4 seconds or until any key is pressed:

> *"Long-press dotted keys for IPA • Open IPA Keyboard app for help"*

After 3 activations, never shown again. Counter stored in the extension's own UserDefaults (`activationCount: Int`). Occupies the vertical space where a prediction bar would otherwise sit — no layout cost.

### 4.7 Memory budget

iOS keyboard extensions crash if resident memory exceeds ~48 MB.

- **No images** inside the extension target (text-only UI).
- **No JSON parsing at runtime** — mapping is a compiled Swift struct from codegen.
- **No third-party dependencies** in the extension.
- Every new allocation on the typing hot path is reviewed against this ceiling.
- CI preflight: size-delta check (§9) catches silent growth.

---

## 5. Container app

### 5.1 Three tabs (SwiftUI `TabView`)

```
┌── Reference  (default after setup is confirmed)
├── Setup      (default on first launch; always accessible after)
└── About
```

### 5.2 Setup tab

```
┌─────────────────────────────────────────────┐
│  STEP 1 OF 1 · ACTIVATE KEYBOARD            │
│  Enable IPA Keyboard                        │
│                                             │
│  Follow these steps in the Settings app:    │
│                                             │
│  ①  Open Settings                           │
│  ②  Go to General → Keyboard → Keyboards    │
│  ③  Tap "Add New Keyboard…" → IPA Keyboard  │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  Try it here                                │
│  ┌───────────────────────────────────────┐  │
│  │ …                                     │  │
│  └───────────────────────────────────────┘  │
│  Tap the globe 🌐 to switch to IPA Keyboard │
│                                             │
│  [ I've done this ]   (secondary)           │
│                                             │
│  ═══════════════════════════════════════    │
│  [       Open Settings        ] ◀── primary │
│  Keyboard not appearing in Settings? →      │
└─────────────────────────────────────────────┘
```

**Rules:**
- Layout is **always visible** — not a wizard. Users can glance back mid-navigation.
- **"STEP 1 OF 1"** caption above the title frames this as a one-time milestone so users don't feel like they've entered a multi-screen onboarding funnel. It's literally the only setup this app ever asks for.
- Steps are rendered as **non-interactive numbered circles (①②③)**, not tappable checkboxes. iOS cannot verify any of them, so letting users "mark them done" invited the false impression that the app knew they had. Reading the number is the point; no state to track.
- **Primary CTA is sticky at the bottom of the screen: `[ Open Settings ]`.** Uses `UIApplication.openSettingsURLString`. Copy is honest that this drops users at the app's Settings page (iOS no longer supports deep-linking to the Keyboards subpath). Steps ② and ③ tell them where to navigate from there. Bottom placement matches thumb reach on iPhone.
- **Troubleshooting link** directly beneath the CTA: `Keyboard not appearing in Settings? →` opens a sheet described in §5.2.1.
- "Try it here" field scans input text on every change for any character in the `SymbolDetector.allKnownVariants` set. First match → `sawIpaCharacterInTestField = true` → helper text animates to "Looks like it's working ✓" (subtle, system green). **Paste counts.** Once flipped to `.working`, we stay there; no un-confirm.
- **The `sawIpaCharacterInTestField` variable does not gate any feature** anywhere in the app. It only affects the color + text of one label. Any UI branch based on it would overreach — the value is a soft local observation, not a truth claim about system state.
- "I've done this" (secondary button, above the primary CTA divider) collapses the main layout into a "✓ Setup complete — keyboard ready to use" banner with a "Show steps again" link. Sets `hasConfirmedSetup = true`, which changes the default-launched tab from Setup → Reference on next launch. The "Open Settings" CTA and troubleshooting link remain visible in the collapsed state — users can re-open Settings any time.

### 5.2.1 Troubleshooting sheet

Modal sheet (`.sheet`) presented over the Setup tab. Static content, no network, no state:

```
Keyboard not appearing in Settings?

• Make sure you're on iOS 17 or later. (IPA Keyboard
  requires iOS 17+ — check Settings → General → About.)
• Fully quit the Settings app (swipe up from bottom and
  flick Settings away), then reopen it. iOS sometimes
  caches the keyboards list.
• Restart your iPhone. After a fresh install, iOS can
  take a moment to register the new keyboard extension.
• Still not working? Delete IPA Keyboard, reinstall from
  the App Store, and try again.

                         [ Close ]
```

- No "Contact support" affordance in v1 (we have no support email set up, and the "Free distribution, no accounts" constraint argues against adding one).
- Content is static Swift strings, not a remote URL. Offline-first is non-negotiable per CLAUDE.md.

### 5.3 Reference tab

Scrollable table of the 11 base letters → their IPA variants:

| Key | Variants (tap to copy) | Names / example words |
|---|---|---|
| `a` | `æ` `ʌ` `ɑː` | Ash (cat) · Wedge (up) · Long open back (far) |
| `e` | `ə` `ɜː` | Schwa (teacher) · Long open-mid central (bird) |
| *…all 11 rows* | | |

Tapping a variant copies it to the system clipboard and shows a toast (`Copied æ`) for ~2s. Tap-to-copy is debounced per-value (`clipboardDebounceInterval`) — the 6th rapid tap on the same variant within 300ms is a no-op; a tap on a *different* variant immediately is accepted.

### 5.4 About tab

- App version (from `Info.plist`)
- One-paragraph privacy statement: "This app collects no data. It works entirely offline. No accounts, no analytics, no network."
- Licenses (open-source components if any — expected: none in v1)

No settings toggles. Not faking a Settings tab whose toggles have no effect.

---

## 6. Data flow & state

### 6.1 Two isolated state universes

```
┌──────────────────────────────────────┐      ┌──────────────────────────────────────┐
│  Container app (IPAKeyboardApp)      │      │  Keyboard extension                  │
│                                      │      │  (IPAKeyboardExtension)              │
│  UserDefaults (app's own suite)      │      │  UserDefaults (extension's own suite)│
│   · hasConfirmedSetup: Bool          │      │   · activationCount: Int             │
│   · defaultTab: .reference/.setup    │ ╳    │                                      │
│   · sawIpaCharacterInTestField: Bool │      │  In-memory @State only:              │
│                                      │      │   · isShifted: Bool                  │
│                                      │      │   · activeTouch: (Character, UUID)?  │
│  Clipboard (system-wide)             │      │   · popoverSelectedIndex: Int?       │
│   · writes on Reference-tab tap      │      │                                      │
└──────────────────────────────────────┘      └──────────────────────────────────────┘
                    │                                             │
                    └──── both read from (read-only) ─┐     ┌─────┘
                                                     ▼     ▼
                                          ┌──────────────────────────┐
                                          │  IPACore (local SPM pkg) │
                                          │  · IPAMapping (generated)│
                                          │  · SymbolReference (gen) │
                                          │  · LayoutEngine          │
                                          │  READ-ONLY at runtime    │
                                          └──────────────────────────┘
```

The `╳` is load-bearing: no App Group, so no UserDefaults sharing. Each target is hermetic.

### 6.2 Design principles (enforced)

1. **Text lives in the host app only.** `insertText(...)` is fire-and-forget, best-effort, not guaranteed. The keyboard holds no copy, never reads host text back, never verifies insertion. Eliminates sync/privacy/state-corruption bugs by construction.
2. **All keyboard-extension state is a pure function of the current touch.** Lifecycle resets (iOS killing and recreating the extension) are indistinguishable from the user lifting their finger. No persistence needed, no recovery logic needed.
3. **`sawIpaCharacterInTestField` cannot gate UI features.** Only the helper-label text and color depend on it. Any other branch is a code smell.

### 6.3 Future-proofing (not built in v1)

If v1.1 adds optional user customization (theme, variant reorder, haptic toggle) via Full Access + App Group, the contract will be:

- **The container app writes to the App Group's UserDefaults; the keyboard only reads.**
- No mutual writes, no two-way sync. Eliminates extension-side race conditions.
- With Full Access refused, the keyboard falls back to bundled defaults and the container-app toggles are grayed out with an explanation.

---

## 7. Error handling

Principle: **fail silently and recoverably in UX; fail loudly in tests and CI.** No error dialogs from a keyboard extension — forbidden by iOS HIG.

### 7.1 Keyboard extension runtime failures

| Failure | Response |
|---|---|
| `textDocumentProxy` nil / weird | Guard every insert/delete; no-op on absence. User retaps. |
| iOS memory warning | Dismiss popover, release font caches, log signpost. No crash. |
| Extension terminated mid-use | Handled by design — state is pure function of current touch (see §6.2). |
| Popover would clip screen edge | Edge-aware positioning (mirror, then scroll) — never off-screen. |
| Gesture cancelled (phone call, Control Center, orientation change) | `touchesCancelled` clears state; same code path as a normal end with no insertion. UUID-token pattern (§4.4) prevents late-timer races. |
| Haptics unavailable (older hardware, some Low Power modes) | `HapticsService` checks availability once and no-ops when absent. |
| Grapheme-boundary deletion (e.g., `dʒ`, `ɑː` + backspace) | Use `textDocumentProxy.deleteBackward()` once; iOS handles grapheme clusters correctly. We never roll our own codepoint math. |
| Codegen'd `IPAMapping.swift` malformed | Can't happen at runtime — it's compiled Swift. If it were garbage, the build would fail. |

### 7.2 Container app runtime failures

| Failure | Response |
|---|---|
| `openSettingsURLString` returns `false` | Fall back to an alert: "Couldn't open Settings — please open it manually." |
| Clipboard write fails | Fire-and-forget; show toast regardless. Users retap if it didn't stick. |
| UserDefaults write fails (disk full — rare) | No check. Worst case: checklist doesn't persist; user reticks. |
| App foregrounded days after onboarding | UI is stateless at this level — rendered from UserDefaults. Checklist is always visible. |
| iOS changes Settings deep-link target in future | No code change needed — steps 2 & 3 of the checklist tell users where to navigate from wherever Settings lands. |

### 7.3 Non-errors we deliberately don't handle

- **User types IPA into a read-only field.** Host app's problem, not ours.
- **User installs on iOS < 16.** `MinimumOSVersion` gates this at App Store download.
- **"Allow Full Access" state.** We don't request it, so N/A.
- **Keyboard permissions revoked in Settings.** iOS simply stops calling our extension. User sees it drop from the 🌐 cycle.
- **Host app transforms or rejects inserted text.** Smart punctuation, autocorrect, replacement rules, custom `UITextField` delegates can alter what we insert (e.g., a host replaces `tʃ` with `t'ʃ`). We treat `insertText` as best-effort; we fire once, trust iOS, don't read back to verify. If this becomes a common support issue we add a troubleshooting entry in About pointing at host-app settings like Notes' "Smart Punctuation".

---

## 8. Testing strategy

### 8.1 Unit tests (`IPACoreTests`, XCTest)

- `IPAMappingTests`: generated `IPAMapping.swift` round-trips every entry in `default-mappings.json` verbatim.
- `LayoutEngineTests`: popover positioning math at all edges, narrow widths (320pt), mirroring rule.
- `SymbolDetectorTests`: all 18 IPA variants trigger detection; no normal ASCII does; pasted strings count.
- `CodegenIntegrityTests`: every JSON key has a matching Swift constant, and vice versa.

Runs on every PR in CI. Fast.

### 8.2 Snapshot tests (`swift-snapshot-testing`, committed images)

Covering size-class matrix:

- iPhone SE portrait / landscape
- iPhone 15 portrait / landscape
- iPad portrait / landscape
- iPad floating-keyboard width (~320pt)
- iPad split-keyboard (half width)

For each:

- Full keyboard (alpha layer + numbers layer + symbols layer)
- Popover rendered on worst-case corner keys (`a`, `p`, `z`, `n`)
- Light mode + dark mode
- Shift on + shift off

Snapshot diffs gate PRs. Never-off-screen is the explicit assertion on every popover snapshot.

### 8.3 UI tests (`IPAKeyboardAppUITests`, XCUITest on simulator)

- **Setup tab:** "I've done this" collapses the layout and persists across relaunch; default-tab flips to Reference on next launch; numbered circles render as non-interactive (tap is a no-op); troubleshooting sheet opens and closes cleanly.
- **Reference tab — clipboard contract:**
  - Tap variant → clipboard matches exactly
  - Toast **appears within 200ms** (existence assertion)
  - Toast **disappears by 2500ms** (inverse existence assertion)
- **Reference tab — rapid-tap debounce:** 5 rapid taps on the same variant within 500ms → clipboard writes exactly once → exactly one toast in view.
- **Reference tab — different-variant sequence:** tap `æ`, wait 150ms (inside debounce), tap `ʌ` → second tap accepted, clipboard = `ʌ`. Debounce is per-value, not per-tap.
- **About tab:** rendered version matches `Info.plist`.

### 8.4 Manual test checklist (`docs/ios/manual-test-checklist.md`, re-run every release)

Things automation can't reliably catch:

- Clean install → enable keyboard from Settings → type in: Messages, Notes, Safari URL bar, Safari web form, Mail, WhatsApp, Discord, Twitter, Google Docs.
- Globe-switch mid-typing session to/from system keyboard.
- **Third-party-keyboard coexistence stress.** Install at least two other third-party keyboards (Gboard, SwiftKey). Start a long-press on a dotted key (popover visible); rapidly globe-cycle 5+ times. Verify: no crash, no stuck popover, no phantom insertion from cancelled gesture. Return → fresh long-press still works.
- Physical iPhone SE and iPad tested (simulators don't reproduce floating/split reliably).
- VoiceOver: each IPA variant announced with its name from `LocalizedSymbolNames`.
- Dynamic Type at AX3: container app scales; keyboard keys stay at native-keyboard sizes (by design).
- Low Power Mode: haptics no-op gracefully.
- Memory soak: 10 min continuous keyboard use without crash or perceptible lag.
- **ASCII-capable fields offer us.** Verify the keyboard is offered (and switchable in) inside a login form, a plain `UITextField`, and any `UIKeyboardType.asciiCapable` field.
- **Restricted contexts.** Confirm we do NOT appear in secure password fields (iOS enforces this regardless).

### 8.5 Pre-release integration

- TestFlight beta ≥1 week with 5–10 target-audience users (linguistics students/researchers).
- ≥1 tester on iPhone SE, ≥1 on iPad.
- Zero blocking regressions before submission.

---

## 9. App Store submission criteria

### 9.1 Bundle identifiers

- Container: `com.minhphan.ipa-keyboard-ios`
- Extension: `com.minhphan.ipa-keyboard-ios.keyboard`

Distinct from the existing macOS bundle ID `com.minhphan.ipa-keyboard` — they are separate apps.

### 9.2 Entitlements

**Both targets: empty entitlements.** No network, no App Group, no sandbox exceptions. No Full Access on the extension. This is the key review-friendliness decision.

### 9.3 Extension `Info.plist` (required keys)

```xml
<key>MinimumOSVersion</key>
<string>16.0</string>
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

**`IsASCIICapable` = `YES`.** Our keyboard produces normal a–z on plain taps — those are ASCII — so we are ASCII-capable. The IPA variants on long-press are incidental. Setting `NO` would hide us from legitimate ASCII-restricted contexts; we want to be available there.

**`RequestsOpenAccess` = `NO`** — the explicit Full Access refusal.

### 9.4 `PrivacyInfo.xcprivacy` (both targets, identical)

```xml
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
```

`CA92.1` = "access info stored in UserDefaults that is accessible only to the app itself." This is required because we use `UserDefaults` in both targets (`hasConfirmedSetup`, `defaultTab`, `sawIpaCharacterInTestField`, `activationCount`). Omission is a common App Store rejection.

Other APIs we use and their privacy-manifest status:

| API | On required-reason list? | Action |
|---|---|---|
| `UserDefaults` (both targets) | **Yes** | Declared with `CA92.1` |
| `UIPasteboard` (container only) | No (governed via pasteboard prompt, not manifest) | None needed |
| `UIImpactFeedbackGenerator`, `playInputClick()` | No | None needed |
| `UIApplication.openSettingsURLString` | No | None needed |
| File-timestamp / boot-time / disk-space / active-keyboard-info APIs | Not used | N/A |

### 9.5 App Store Connect metadata

| Field | Value |
|---|---|
| Category | Utilities |
| Age Rating | 4+ |
| Price | Free, no IAP, no ads |
| Data Used to Track You | None |
| Data Linked to You | None |
| Data Not Linked to You | None |
| Supported Devices | iPhone, iPad |

### 9.6 Review notes template

```
IPA Keyboard is an alternate iOS keyboard for typing IPA (International
Phonetic Alphabet) symbols, for linguistics students and researchers.

Fully offline — no network, no accounts, no data collection, no analytics.

PERMISSIONS
  • RequestsOpenAccess: NO — the keyboard does not request Full Access.
  • No App Group. No network entitlement. No sandbox exceptions.
  • Privacy manifest declares no tracking, no collection, no tracking domains.

HOW TO TEST
  1. Install, open the app.
  2. On the Setup tab, tap "Open Settings".
  3. In Settings: General → Keyboard → Keyboards → Add New Keyboard → IPA Keyboard.
     (Do NOT enable Full Access — the keyboard does not use it.)
  4. Return to our app. Tap the "Try it here" field, press 🌐, switch to IPA Keyboard.
  5. Long-press any of the dotted letters (a e i o u t s d c n z) to choose an IPA variant.
  6. Verify typing works in any app with a text field.

The IPA symbol set is standard Unicode used in linguistics textbooks; it is a
subset of the Latin Extended IPA block.
```

### 9.7 Pre-submission checklist (`docs/ios/submission-checklist.md`)

- [ ] `RequestsOpenAccess = NO` in extension `Info.plist`
- [ ] `IsASCIICapable = YES` in extension `Info.plist`
- [ ] `PrivacyInfo.xcprivacy` present in both targets, declares `CA92.1` for `UserDefaults`
- [ ] No network / App Group / Full Access entitlements
- [ ] CI preflight green: codegen fresh, forbidden-APIs grep clean, extension size within 5% of baseline
- [ ] All unit + snapshot + UI tests green
- [ ] Manual checklist signed off (including keyboard coexistence stress, ASCII-field offering, VoiceOver)
- [ ] Apple privacy-report tool run against the built app; output matches the manifest
- [ ] TestFlight ≥1 week; ≥1 tester on iPhone SE, ≥1 on iPad; no blocking regressions
- [ ] Screenshots captured: iPhone 6.7" + 6.1"; iPad 12.9" + 11"
- [ ] App Store Connect: description, keywords, support URL, privacy policy URL populated
- [ ] Distribution-signed build uploaded via Transporter or `xcrun altool`

### 9.8 CI preflight (`ios/Scripts/preflight.sh`)

| Check | Failure mode |
|---|---|
| Codegen freshness: SHA256 of `shared-config/default-mappings.json` matches the header of `IPACore/Sources/IPACore/IPAMapping.swift` | Fail with diff |
| `PrivacyInfo.xcprivacy` exists in both targets, declares no tracking + `CA92.1` for UserDefaults | Fail on mismatch |
| Required-reason APIs: grep source for `UserDefaults` usage → verify declared in manifest | Fail on drift |
| Entitlements: neither target has `com.apple.security.network.client`, App Group, or Full Access entries | Fail on drift |
| No network code: `grep -RE 'URLSession\|NWConnection\|\\.network' ios/` returns nothing outside of clearly-marked example comments | Fail on any hit |
| Forbidden APIs in extension (`IPAKeyboardExtension/`): no `UIPasteboard`, no `CLLocation`/`CLLocationManager`, no `ASIdentifierManager`, no `advertisingIdentifier`, no `AVAudioSession`/`AVAudioEngine`/`AVAudioRecorder`, no `CNContact`, no `PHPhotoLibrary`, no `UIDevice.current.identifierForVendor` | Each check is a separate step; a failure names the specific violation and why it's forbidden |
| Extension binary size: stripped arm64 slice within 5% of baseline in `Scripts/baseline-sizes.json` | Fail on regression; intentional bumps via `Scripts/update-baseline.sh` appear in PR diff |
| IPA symbol round-trip: every `(key, variants)` in the JSON produces the exact symbols in the generated struct | Fail on codegen regression |

---

## 10. Scope boundaries / non-goals (v1)

Explicit list so nothing drifts in:

- No document editor in the container app
- No favorites or recents in either target
- No search in the Reference tab (11 rows; search adds no value)
- No user-configurable keyboard behavior (theme, variant order, haptic toggle) — locked by the no-Full-Access decision
- No iCloud sync, no accounts, no cloud anything
- No analytics, no telemetry, no third-party SDKs (crash reporting included)
- No network access anywhere; enforced by CI grep
- No App Group, no Full Access
- No autocorrect, predictive text, or custom dictionary
- No extIPA, SIL, historical, or multi-language IPA symbols — only what is in `shared-config/default-mappings.json`
- No emoji, GIF, or sticker surfaces
- No Apple Watch, Vision Pro, or macOS Catalyst
- No iPad split-keyboard custom layout (adaptive only)
- No widget, Shortcuts integration, Siri, or Spotlight
- No Mac App Store sibling — deferred to a separate follow-up project

---

## 11. Open questions (to be resolved during implementation, not blockers for this spec)

- **Exact coach-mark copy and styling.** Direction is "translucent pill above top row, fades in on first 3 activations." Wording and precise opacity are implementation polish.
- **Toast duration tuning.** Currently specified as ~2s + debounced at 300ms. May adjust after TestFlight feedback.
- **Variant-popover visual style.** Matches iOS system style by default; minor tweaks (font weight, padding) acceptable during implementation as long as snapshot tests pass.
- **Symbol-reference localization.** v1 ships English names from `ipa-names.ts` via generated `LocalizedSymbolNames.swift`. Future localization is a v1.x concern.

---

## 12. References

- `CLAUDE.md` — project constraints (offline-first, free, no telemetry)
- `shared-config/default-mappings.json` — single source of truth for symbol mapping
- `docs/DISTRIBUTION.md` — why the existing macOS daemon cannot be sandboxed / App-Store-distributed
- `docs/MAC-APP-STORE-GUIDE.md` — prior work on Mac App Store submission (Tauri companion app)
- `companion-app/src/data/ipa-symbols.json` — symbol reference data, to be ported into `IPACore/SymbolReferenceData.swift` via codegen
- `companion-app/src/data/ipa-names.ts` — symbol names, to be ported into `IPACore/LocalizedSymbolNames.swift` via codegen

---

## 13. Next step

Write an implementation plan via the `superpowers:writing-plans` skill, structured per the user's convention: `PLAN.md` at the repo root (updated or sibling section) + per-phase files `phase-<n>-<slug>.md` containing `- [ ]` checkboxes for progress tracking.
