---
layout: default
title: Support — IPA Typing Keyboard
---

# Support

## Quick start

1. Open **IPA Typing Keyboard** after installing
2. Tap **Open Settings** on the Setup tab
3. In iOS Settings: **General → Keyboard → Keyboards → Add New Keyboard →
   IPA Typing Keyboard**
4. Return to the app, tap the **Try it here** field
5. Press the 🌐 globe key on the keyboard to switch to **IPA Typing Keyboard**
6. **Long-press** any of the dotted letters (a, e, i, o, u, t, s, d, c, n, z)
   to pick an IPA variant

## FAQ

### The keyboard doesn't appear after I add it

Switch keyboards using the 🌐 globe key in any text field. iOS does not
automatically show a new keyboard until you select it with the globe key.
If the globe key is missing, you can also touch and hold the emoji key, then
choose the keyboard from the list.

### I don't see all IPA symbols

Most IPA characters live behind long-press popovers on the **dotted** letters:
a, e, i, o, u (vowels), and t, s, d, c, n, z (consonants). Long-press one,
hold, then slide your finger to the variant you want.

For a full list of supported symbols, open the **Reference** tab in the app
— tap any symbol to copy it to the clipboard.

### Why is there no haptic feedback / vibration when I long-press?

iOS restricts haptic feedback in keyboard extensions to keyboards with
**Full Access** enabled. Because IPA Typing Keyboard does **not** request
Full Access (so we can guarantee that none of your typed text ever leaves
your device), iOS may silently disable haptics. A subtle selection tick may
still fire on some devices.

If you want the standard iOS keyboard haptic intensity, that requires
trusting the keyboard with Full Access — a trade-off we deliberately
declined for v1.

### Why doesn't the popover appear above the top-row keys (E, T, U, I, O)?

For v1, the long-press popover for top-row keys appears at the top edge of
the keyboard area, overlapping the long-pressed key. Apple's built-in
keyboard renders this popover above the keyboard frame, into the host app's
display area; matching that exactly is on our v1.1 roadmap.

### Does the keyboard work in landscape / on iPad?

Yes. The keyboard adapts to all iPhone widths from iPhone SE through 6.9",
and to all iPad widths including the floating iPad keyboard.

### Can I sync my settings between devices?

No. The app stores no data outside your device. This is by design — there
are no accounts, no cloud sync, and no analytics.

## Report a bug or request a feature

Open an issue:
[https://github.com/minhpnz/ipa-keyboard/issues](https://github.com/minhpnz/ipa-keyboard/issues)

Or email: **minh.phan81299@gmail.com**

## Privacy

See the [Privacy Policy](privacy.html). Short version: no data leaves your
device, ever.
