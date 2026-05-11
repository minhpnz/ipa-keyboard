# TestFlight feedback — IPA Typing Keyboard v1.0.0

Internal-only log of issues reported during the external beta. The rule
(Phase 8 spec §8.5 / Task 8.4 Step 3): anything blocking typing IPA
symbols, crashing the extension, or breaking Setup ships fixed before
submission. Cosmetic issues can carry into v1.1.

External beta started: 2026-05-11 (build 1.0.0 (2) submitted for Beta App
Review)

Required tester mix for spec compliance: ≥1 iPhone SE tester +
≥1 iPad tester + ≥7 days of stable beta use.

---

## Open issues

| Tester | Device / iOS | Date | Finding | Severity | Fix in build? |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

## Resolved issues

| Tester | Device / iOS | Date | Finding | Resolution |
|---|---|---|---|---|
| Self | iPhone 11 / iOS 18.7 | 2026-05-11 | Top-row popover (E, T, U, I, O) appears below the key, hiding it behind row 2 | Fixed in 1.0.0 (2) — LayoutEngine clamps to keyboard top instead of mirroring below |
| Self | iPhone 11 / iOS 18.7 | 2026-05-11 | Popover show/hide felt instant, not animated | Fixed in 1.0.0 (2) — `withAnimation(.easeOut)` wraps state changes |
| Self | iPhone 11 / iOS 18.7 | 2026-05-11 | No haptic on long-press appear | Fixed in 1.0.0 (2) — `HapticsService.selection()` fires at appear + drag-snap |

## Build history

| Build | Date | Reason | Status |
|---|---|---|---|
| 1.0.0 (1) | 2026-05-11 | Initial TestFlight upload | Superseded by (2) |
| 1.0.0 (2) | 2026-05-11 | Long-press UX fixes (top-row popover + animation + haptic call sites) | **Active beta** |

## Closing criteria (spec §8.5)

- [ ] ≥1 week elapsed since the first external invite
- [ ] ≥1 confirmed iPhone SE tester
- [ ] ≥1 confirmed iPad tester
- [ ] No unresolved blockers in the open-issues table above
- [ ] Privacy report tool run against the build — output matches the manifest

When all four are checked, proceed to Task 8.7 (final submission).
