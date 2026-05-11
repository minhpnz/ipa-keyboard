# App Store screenshots — IPA Typing Keyboard iOS

5 screenshots per size class. Same 5 scenes captured across iPhone 6.9" and
iPad 13" (the two required primary classes for post-iOS-26 App Store Connect —
Apple auto-scales the 6.9" shots for smaller iPhones and the 13" shots for
smaller iPads, so older classes are no longer mandatory).

Captured 2026-05-11 from build `1.0.0 (2)` on iOS 26.4 simulator.

## Upload order (App Store Connect)

Upload in this numeric order so the App Store page reads as a narrative:
**use the keyboard → see the result → walk through the app**.

| # | File | Scene | Why this shot |
|---|---|---|---|
| 1 | `01-popover-a.png` | Long-press popover open on `a` showing `æ ʌ ɑː ɑ` | Hero shot: the long-press gesture is the app's distinctive feature |
| 2 | `02-typed-result.png` | `pæθ` typed in the in-app field with "Looks like it's working ✓" | Proves the keyboard actually inserts IPA characters in real text fields |
| 3 | `03-setup.png` | Setup tab clean state | First impression of the container app |
| 4 | `04-reference-toast.png` | Reference tab mid-copy with "Copied æ" toast | Shows the symbol-browser fallback for users who don't want long-press |
| 5 | `05-about.png` | About tab showing version + privacy statement | Reinforces the privacy story right before the user installs |

## Size classes captured

| Class | Folder | Resolution | Simulator |
|---|---|---|---|
| iPhone 6.9" Display | `iphone-6.9/` | 1320 × 2868 | iPhone 17 Pro Max (iOS 26.4) |
| iPad 13" Display | `ipad-13/` | 2064 × 2752 | iPad Pro 13-inch (M5, iOS 26.4) |

Older size classes (iPhone 6.7" / 6.5", iPad 12.9"): NOT captured. ASC accepts
the 6.9" + 13" shots as fallbacks for smaller devices since iOS 17.

## App Previews (videos)

None for v1. The keyboard + popover gesture is well represented by the static
shots and a video adds disproportionate review surface for a v1.0 ship.

## Regenerating

If the keyboard's visual style changes or the app's tab layout shifts,
re-capture. Process:

1. Boot the relevant simulator: `xcrun simctl boot <udid>`
2. Build for that simulator destination + install: see
   `ios/Scripts/preflight.sh` for the `xcodebuild build` invocation
3. Walk through the 5 scenes by hand in the simulator
4. Capture each: `xcrun simctl io <udid> screenshot <path>`
5. Verify dimensions: `sips -g pixelWidth -g pixelHeight <path>`

The capture command writes pixel-accurate PNGs at the simulator's native
device resolution — no need to use the simulator window's Cmd+S which
applies scaling.
