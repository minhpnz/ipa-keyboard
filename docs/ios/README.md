# iOS Sub-project — `ios/`

An iOS App Store app. Third-party keyboard extension + minimal container app.

**Design spec:** `docs/superpowers/specs/2026-04-21-ios-ipa-keyboard-design.md`
**Plan:** [`ios/PLAN.md`](../../ios/PLAN.md)
**Submission checklist:** [`submission-checklist.md`](submission-checklist.md)
**Manual test checklist:** [`manual-test-checklist.md`](manual-test-checklist.md)
**Reviewer notes template:** [`review-notes.md`](review-notes.md)

## Build locally

```
cd ios/
open IPAKeyboard.xcodeproj
```

Scheme: `IPAKeyboardApp`. Run on any iOS 16+ simulator.

## Run preflight

```
./Scripts/preflight.sh
```

## Regenerate codegen after mapping changes

```
./Scripts/generate-ipa-mapping.sh
```

Commit the generated `IPAMapping.swift`, `SymbolReferenceData.swift`, and `LocalizedSymbolNames.swift`.
