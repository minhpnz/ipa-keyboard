# iOS IPA Keyboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-04-21-ios-ipa-keyboard-design.md`

**Goal:** Ship an iOS third-party keyboard (iPhone + iPad, iOS 16+) to the Apple App Store that types IPA symbols via iOS-native long-press popovers, plus a minimal container app for onboarding and symbol reference. Offline-first, no Full Access, no App Group.

**Architecture:** Two iOS targets — `IPAKeyboardApp` (container) and `IPAKeyboardExtension` (keyboard) — sharing read-only code via a local Swift Package `IPACore`. Keyboard extension hosts SwiftUI inside `UIInputViewController` via `UIHostingController`. Mapping data is a compiled Swift struct, generated at build-time from `shared-config/default-mappings.json` and committed to the repo. No network, no telemetry, no third-party dependencies in the extension.

**Tech stack:** Swift 5.9+, SwiftUI, UIKit (`UIInputViewController`), Swift Package Manager (local package), XCTest, `swift-snapshot-testing`, XCUITest, bash/jq for codegen, Xcode 15+.

**Plan placement note:** The repo root `PLAN.md` belongs to the existing macOS/Windows IME + Tauri companion app workstream. This iOS sub-project is self-contained under `ios/` per spec §3 and gets its own plan tree here.

---

## Phase index

| # | Phase | File | What ships |
|---|---|---|---|
| 1 | Foundation | [phase-1-foundation.md](phases/phase-1-foundation.md) | Xcode project, both targets wired, `IPACore` SPM package, codegen script, `LayoutEngine`/`SymbolDetector`, first unit tests |
| 2 | Keyboard alpha layer | [phase-2-keyboard-alpha.md](phases/phase-2-keyboard-alpha.md) | QWERTY keys, blue-dot indicators, shift, function row, tap-to-insert; snapshot tests |
| 3 | Long-press popover | [phase-3-popover.md](phases/phase-3-popover.md) | UUID-token gesture state machine, `VariantPopover` edge-aware geometry, haptics, drag-select |
| 4 | Numbers / symbols / coach mark | [phase-4-numbers-coach.md](phases/phase-4-numbers-coach.md) | `123` digits + `#+=` symbols layers, layer switching, coach-mark banner on first 3 activations |
| 5 | Container app: Setup tab | [phase-5-setup-tab.md](phases/phase-5-setup-tab.md) | `RootTabView`, `SetupView` with sticky CTA + numbered circles, troubleshooting sheet, "Try it here" detector |
| 6 | Container app: Reference + About | [phase-6-reference-about.md](phases/phase-6-reference-about.md) | Symbol reference with tap-to-copy + per-value debounce + toast; About tab |
| 7 | App Store criteria + CI preflight | [phase-7-app-store-criteria.md](phases/phase-7-app-store-criteria.md) | `Info.plist` keys, `PrivacyInfo.xcprivacy`, empty entitlements, `preflight.sh` with 8 guards, size baseline |
| 8 | TestFlight + submission | [phase-8-submission.md](phases/phase-8-submission.md) | Screenshots, App Store Connect metadata, TestFlight ≥1 week, submission |

---

## Cross-cutting principles (apply to every phase)

1. **TDD.** Write the failing test first. Watch it fail. Write minimal code. Watch it pass. Commit. Repeat.
2. **Frequent commits.** Every task ends with a commit. No task is "done" until committed.
3. **No network code anywhere.** Preflight greps for `URLSession|NWConnection|\.network` and fails on any hit.
4. **Constants, never literals, in logic.** `LayoutEngine.popoverDelay` — not `0.5`. Tests reference the constants too.
5. **Generated files are committed.** Do not rebuild `IPAMapping.swift` etc. in CI. Regenerate on `shared-config/` changes; CI verifies the embedded SHA256 matches.
6. **No images in the extension target.** Text UI only. Protects the ~48 MB memory ceiling.
7. **No third-party SDKs in the extension.** The container app may use `swift-snapshot-testing` (a test-only dep); it must not ship in the extension binary.
8. **Both targets have empty entitlements files in v1.** No App Group, no network, no Full Access. The privacy story IS a feature.
9. **The keyboard never reads host-app text back.** `insertText` is fire-and-forget. This is non-negotiable — it eliminates entire bug classes by construction.

---

## Overall status

- [x] Phase 1 — Foundation
- [x] Phase 2 — Keyboard alpha layer
- [x] Phase 3 — Long-press popover
- [ ] Phase 4 — Numbers / symbols / coach mark
- [ ] Phase 5 — Container app: Setup tab
- [ ] Phase 6 — Container app: Reference + About
- [ ] Phase 7 — App Store criteria + CI preflight
- [ ] Phase 8 — TestFlight + submission

Mark each phase as done by ticking the box above **and** confirming every `- [ ]` in the phase file is ticked.

---

## File-structure lock (from spec §3)

```
ios/
├── IPAKeyboard.xcodeproj
├── IPAKeyboardApp/                      (container target)
│   ├── IPAKeyboardAppApp.swift
│   ├── Views/
│   │   ├── RootTabView.swift
│   │   ├── SetupView.swift
│   │   ├── TroubleshootingSheet.swift
│   │   ├── ReferenceView.swift
│   │   └── AboutView.swift
│   ├── Assets.xcassets
│   ├── PrivacyInfo.xcprivacy
│   ├── Info.plist
│   └── IPAKeyboardApp.entitlements       (empty dict)
├── IPAKeyboardExtension/                 (keyboard target)
│   ├── KeyboardViewController.swift
│   ├── Views/
│   │   ├── KeyboardRootView.swift
│   │   ├── KeyRow.swift
│   │   ├── KeyView.swift
│   │   ├── VariantPopover.swift
│   │   ├── NumbersLayerView.swift
│   │   ├── SymbolsLayerView.swift
│   │   └── CoachMarkBanner.swift
│   ├── Services/
│   │   ├── HapticsService.swift
│   │   └── InputClickService.swift
│   ├── Assets.xcassets
│   ├── PrivacyInfo.xcprivacy
│   ├── Info.plist
│   └── IPAKeyboardExtension.entitlements (empty dict)
├── IPACore/                              (local SPM package)
│   ├── Package.swift
│   └── Sources/IPACore/
│       ├── IPAMapping.swift              (GENERATED, committed)
│       ├── SymbolReferenceData.swift     (GENERATED, committed)
│       ├── LocalizedSymbolNames.swift    (GENERATED, committed)
│       ├── LayoutEngine.swift
│       └── SymbolDetector.swift
├── Scripts/
│   ├── generate-ipa-mapping.sh
│   ├── preflight.sh
│   ├── update-baseline.sh
│   └── baseline-sizes.json
└── Tests/
    ├── IPACoreTests/
    ├── KeyboardExtensionSnapshotTests/
    └── IPAKeyboardAppUITests/
```

Every phase cites exact paths from this tree. No phase invents a new top-level folder.
Your code will be reviewed by codex.