# App Store Connect metadata — paste-ready

For Task 8.6 in `ios/phases/phase-8-submission.md`. Open
https://appstoreconnect.apple.com → My Apps → **IPA Typing Keyboard** →
sidebar **Distribution** (or **App Information** + **Version 1.0 Prepare for
Submission**) and paste each block into the matching field.

Last updated: 2026-05-11 — app renamed from spec's "IPA Keyboard" to
"IPA Typing Keyboard" because the original name was taken on the App Store.

---

## App Information

| Field | Value |
|---|---|
| **Category — Primary** | Utilities |
| **Category — Secondary** | Education |
| **Content Rights** | "No, it does not contain, show, or access third-party content." |
| **Age Rating** | 4+ (answer "No" / "None" to every questionnaire entry) |
| **Bundle ID** | `com.minhphan.ipa-keyboard-ios` |
| **Primary Language** | English (U.S.) |

---

## Pricing and Availability

- **Price Schedule** → Free → base territory USA → all territories
- **Availability** → All countries/regions

---

## App Privacy (questionnaire)

**Crucial:** answer all three top-level questions as **None**. The
`UserDefaults` storage is local-only and does not count as "data linked to
the user" because it never leaves the device. The privacy manifest's
`CA92.1` declaration is a separate concept.

| Bucket | Answer |
|---|---|
| Data Used to Track You | **None** |
| Data Linked to You | **None** |
| Data Not Linked to You | **None** |

---

## Version 1.0 — Prepare for Submission

### Promotional Text (170 char limit)

```
Type IPA phonetic symbols anywhere on iOS. Long-press dotted letters for variants. Fully offline — no Full Access, no accounts, no data collected.
```

Length: 159 chars ✅

---

### Description (4000 char limit)

```
IPA Typing Keyboard is an iOS keyboard for typing International Phonetic Alphabet symbols, built for linguistics students, phoneticians, language learners, and anyone who needs IPA symbols in daily work.

HOW IT WORKS
Install the app, add IPA Typing Keyboard in Settings, then switch to it with the 🌐 globe key in any app. Tap letters normally for a–z. Long-press any of the dotted letters (a, e, i, o, u, t, s, d, c, n, z) to pick an IPA variant — the same gesture you already know from the built-in iOS é/è popover.

DESIGNED FOR PRIVACY
• No Full Access required — the keyboard runs in Apple's standard sandbox.
• No network, no accounts, no analytics, no third-party SDKs.
• No typed text ever leaves your device. We cannot read what you write.

IPA SYMBOL REFERENCE
The built-in Reference tab shows every supported symbol with its base letter, name, and a tap-to-copy button — handy for research papers, transcription exercises, or language notes.

DEVICE SUPPORT
iPhone and iPad, iOS 16 or later. Adaptive SwiftUI layout for every size from iPhone SE to iPad 12.9".

NOT INCLUDED (intentionally)
No autocorrect, no predictive text, no telemetry, no cloud sync. The keyboard produces what you press — nothing more.
```

---

### Keywords (100 char limit, comma-separated)

```
IPA,phonetic,linguistics,keyboard,phonology,transcription,symbol,unicode,alphabet,speech
```

Length: 89 chars ✅

---

### URLs

| Field | URL |
|---|---|
| **Support URL** | `https://minhpnz.github.io/ipa-keyboard/support.html` |
| **Marketing URL** | `https://minhpnz.github.io/ipa-keyboard/` *(optional — same as support is fine)* |
| **Privacy Policy URL** | `https://minhpnz.github.io/ipa-keyboard/privacy.html` |

> ⚠ All three URLs must resolve before submission. After enabling GitHub
> Pages, open each URL in an incognito window to confirm.

---

### Build selection

In the **Version 1.0** prepare-for-submission page → **Build** → **+** →
select the latest TestFlight build that has cleared **external** beta
review (per spec §8.5, ≥1 week external + ≥1 iPhone SE tester + ≥1 iPad
tester before submission).

---

## Screenshots

Per `docs/ios/screenshots/README.md` (TBD — Task 8.5). Upload to:

- 6.7" iPhone Display → 5 PNGs (iPhone 15 Pro Max, 1290 × 2796)
- 6.1" iPhone Display → 5 PNGs (iPhone 15, 1179 × 2556)
- 12.9" iPad Display → 5 PNGs (iPad Pro 12.9" 6th gen, 2048 × 2732)
- 11" iPad Display → 5 PNGs (iPad Pro 11" 4th gen, 1668 × 2388)

Same 5-shot composition across all 4 size classes:
1. Keyboard in Messages, long-press popover on `a` showing `a æ ʌ ɑː`
2. Keyboard in Notes with `θ` just inserted
3. Setup tab (clean, before "I've done this")
4. Reference tab (a symbol mid-copy, toast visible)
5. About tab

No App Previews (videos) for v1.

---

## App Review Information

### Notes (paste verbatim from docs/ios/review-notes.md)

```
IPA Typing Keyboard is an alternate iOS keyboard for typing IPA (International
Phonetic Alphabet) symbols, for linguistics students and researchers.

Fully offline — no network, no accounts, no data collection, no analytics.

PERMISSIONS
  • RequestsOpenAccess: NO — the keyboard does not request Full Access.
  • No App Group. No network entitlement. No sandbox exceptions.
  • Privacy manifest declares no tracking, no collection, no tracking domains.

HOW TO TEST
  1. Install, open the app.
  2. On the Setup tab, tap "Open Settings".
  3. In Settings: General → Keyboard → Keyboards → Add New Keyboard → IPA Typing Keyboard.
     (Do NOT enable Full Access — the keyboard does not use it.)
  4. Return to our app. Tap the "Try it here" field, press 🌐, switch to IPA Typing Keyboard.
  5. Long-press any of the dotted letters (a e i o u t s d c n z) to choose an IPA variant.
  6. Verify typing works in any app with a text field.

The IPA symbol set is standard Unicode used in linguistics textbooks; it is a
subset of the Latin Extended IPA block.
```

### Contact

| Field | Value |
|---|---|
| First Name | Minh |
| Last Name | Phan |
| Email | minh.phan81299@gmail.com |
| Phone | *(your phone number)* |
| **Demo account** | **Leave blank** — no sign-in |

---

## Submission pre-flight (run before clicking "Add for Review")

- [ ] Promo text, description, keywords pasted exactly as above
- [ ] All three URLs resolve in an incognito browser
- [ ] Privacy answers = None / None / None
- [ ] Build selected from External-beta-cleared TestFlight builds
- [ ] All 4 size classes have 5 screenshots each
- [ ] Review Notes pasted verbatim
- [ ] Contact filled (first, last, email, phone)
- [ ] Demo account left blank
- [ ] `cd ios && ./Scripts/preflight.sh` exits 0
