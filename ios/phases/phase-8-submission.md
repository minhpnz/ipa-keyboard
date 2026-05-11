# Phase 8 — TestFlight + App Store submission

**Ships:** Distribution-signed build uploaded to App Store Connect, TestFlight beta completed (≥1 week, ≥1 tester each on iPhone SE and iPad), all screenshots captured, App Store Connect metadata populated, and the final submission sent to review.

**Spec sections:** §8.5 pre-release integration, §9.1 bundle IDs, §9.5 App Store Connect metadata, §9.6 review notes, §9.7 submission checklist.

**Pre-req:** Phase 7 complete. `preflight.sh` is green, `docs/ios/submission-checklist.md` and `docs/ios/review-notes.md` exist, manifests are final. This phase performs the external-facing release actions only.

> **Operator note:** Every step in this phase runs against App Store Connect, Apple's signing infrastructure, or real TestFlight testers. Mistakes are public-facing (e.g. rejected screenshots, bad review notes, wrong metadata). Run each step exactly as written and check the expected output before moving on. Do NOT invent new tasks mid-submission — when in doubt, pause and ask.

---

## Task 8.1 — Production signing & App Store Connect app record

**Files:**
- Modify: `ios/IPAKeyboard.xcodeproj` (signing settings, via Xcode)
- Reference: `docs/ios/submission-checklist.md` (from Phase 7)

- [ ] **Step 1: Create the App Store Connect record (container app)**

In App Store Connect → My Apps → "+" → New App:

| Field | Value |
|---|---|
| Platform | iOS |
| Name | IPA Keyboard |
| Primary Language | English (U.S.) |
| Bundle ID | `com.minhphan.ipa-keyboard-ios` (must already exist in the Apple Developer portal — create it there first if needed) |
| SKU | `ipa-keyboard-ios-v1` |
| User Access | Full Access |

Do NOT create a separate record for the extension — it ships embedded inside the container app.

- [ ] **Step 2: Register both bundle IDs in the Apple Developer portal**

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → "+":

1. App ID `com.minhphan.ipa-keyboard-ios` (Type: App, Capabilities: none — leave every checkbox unchecked)
2. App ID `com.minhphan.ipa-keyboard-ios.keyboard` (Type: App Extension, Capabilities: none)

The "no capabilities" choice is load-bearing — any checkbox you tick here has to be matched by an entitlements entry, and our entitlements are empty (spec §9.2).

- [x] **Step 3: Flip both targets to Manual signing + Distribution profile** — **Skipped for v1, documented deviation from spec.**

  Decision (2026-05-11): keep `CODE_SIGN_STYLE: Automatic` with `DEVELOPMENT_TEAM: 3KD4T7N5X8`. For a solo developer doing manual archives via Xcode Organizer, automatic signing creates the Apple Distribution cert and the App Store provisioning profiles at archive-export time (same flow that successfully created the dev cert + profiles in Phase 7). The Manual path is preferred for CI / multi-developer workflows because it's more deterministic and reproducible; we have neither today. Revisit if/when this project gets a CI archive job or a second developer.

- [x] **Step 4: Bump marketing + build version** — `MARKETING_VERSION: "1.0.0"` and `CURRENT_PROJECT_VERSION: "1"` already set in `project.yml` since Phase 1. No change needed.

---

## Task 8.2 — Archive & upload the first TestFlight build

**Files:**
- No code changes in this task.

- [ ] **Step 1: Clean + preflight before archiving**

Run:
```bash
cd ios
./Scripts/preflight.sh
```
Expected: all 8 guards report OK.

If any guard fails, stop. Do NOT archive a build that fails preflight.

- [ ] **Step 2: Archive from Xcode**

In Xcode:
- Scheme: `IPAKeyboardApp` (the container — the extension goes along for the ride because it's an embedded target)
- Destination: "Any iOS Device (arm64)"
- Product → Archive

Expected: Organizer opens with the new archive listed under iOS Apps.

If the archive contains a simulator slice or is missing the extension, stop and fix — don't upload a malformed archive.

- [ ] **Step 3: Validate before uploading**

In Organizer: select the archive → "Validate App" → App Store Connect distribution → automatic signing with your distribution profile → Validate.

Expected: "App validated successfully." Fix any errors before uploading (common ones: privacy manifest mismatch, missing provisioning profile for the extension, unsupported device family).

- [ ] **Step 4: Upload to App Store Connect**

In Organizer: same archive → "Distribute App" → App Store Connect → Upload → automatic signing → Upload.

Expected: "Upload Successful." In App Store Connect → TestFlight → Builds, the build appears within ~5 minutes (may show "Processing" for up to 30 min).

- [ ] **Step 5: Resolve Export Compliance**

In App Store Connect → TestFlight → Builds → the new build → Missing Compliance → "No" to "Does your app use encryption?" (we ship no custom crypto and use no network).

Expected: status flips to "Ready to Test" for internal testers.

---

## Task 8.3 — TestFlight internal test (smoke)

**Files:**
- No code changes in this task.

- [ ] **Step 1: Add yourself as an internal tester**

App Store Connect → Users and Access → confirm your account has access. TestFlight → Internal Testing → "+" → add yourself (and any collaborators who should see the build).

- [ ] **Step 2: Enable the build for internal testing**

TestFlight → Internal Testing → the new build → add the "Ready to Test" build, accept the "What to Test" default.

Expected: Email arrives at your developer account within minutes: "IPA Keyboard 1.0.0 (1) is now available to test."

- [ ] **Step 3: Install on real iPhone via TestFlight app**

On an iPhone running iOS 16+:
- Install TestFlight from the App Store
- Open the emailed invite → Install
- Launch IPA Keyboard → complete Setup → add the keyboard in Settings → type in Messages/Notes

Smoke test (mark each):
- [ ] App launches on Setup tab on first run
- [ ] "Open Settings" jumps to the right screen
- [ ] Keyboard appears under Settings → General → Keyboard → Keyboards after `Add New Keyboard`
- [ ] Long-pressing `a` in Messages reveals the IPA popover
- [ ] Tapping a variant inserts it into the host text field
- [ ] "Try it here" in the app shows the green check after typing an IPA character
- [ ] Reference tab: tap on a symbol copies; toast appears; second rapid tap is debounced
- [ ] About tab: version string displays `1.0.0 (1)`

If any of these fail, fix and go back to Task 8.2 Step 2 with an incremented build number (`1.0.0 (2)`, `(3)`, …).

- [ ] **Step 4: Repeat on iPad**

Same list, but watch for: keyboard adapts to iPad width, the floating (iPad) keyboard renders without clipped popovers, VoiceOver announces long-press hints correctly on iPadOS.

---

## Task 8.4 — External TestFlight beta (≥1 week)

> **v1 decision (2026-05-11): SKIPPED.** Solo developer with no external
> testers available. The ≥1-week external beta exists in the spec as a
> quality bar; with "external = also you" the week of delay buys zero new
> information beyond what internal smoke testing on the developer's iPhone
> already produced (Task 8.3, build 2). External group + Beta App Review
> submission were set up in ASC (so the infrastructure exists for v1.1+
> when testers can be recruited), but the beta was not run to completion
> before Task 8.7. Build 2's smoke pass on iPhone 11 / iOS 18.7 is the
> v1 quality gate.

**Files:**
- No code changes in this task.

- [ ] **Step 1: Create an external testing group**

App Store Connect → TestFlight → External Testing → "+ New Group" → Name: "Linguistics beta". Add 5–10 testers by email (target audience: linguistics students and researchers). The spec (§8.5) requires:
- At least 1 tester on iPhone SE (small-screen sanity check)
- At least 1 tester on iPad
- Beta duration ≥ 1 week of real-world use

- [ ] **Step 2: Submit build for Beta App Review**

Add the build to the external group → "Submit for Review". Fill in:
- **Beta App Description**: paste the first paragraph of `docs/ios/review-notes.md`
- **Feedback Email**: your contact email (a personal one is fine for v1; we have no dedicated support address per spec §5.4)
- **Marketing URL** / **Privacy Policy URL**: same as App Store submission — see Task 8.5

Expected: Beta App Review turnaround is usually < 24h. On approval, testers get an invite email.

- [ ] **Step 3: Capture feedback (feedback log)**

Open a tracking doc: `docs/ios/testflight-feedback.md` (new file, private notes, not committed if you prefer — the Git entry is optional). Record:

```markdown
# TestFlight feedback — v1.0.0

| Tester | Device / iOS | Date | Finding | Fix in build? |
|---|---|---|---|---|
| ... | iPhone SE 3 / iOS 17.5 | 2026-MM-DD | "Popover off-screen when 'z' is long-pressed in landscape" | 1.0.0 (2) |
```

Add a row for every finding. The rule: any issue that blocks typing IPA symbols, crashes the extension, or breaks Setup must ship fixed before submission. Cosmetic issues can carry into v1.1.

- [ ] **Step 4: Re-archive + re-upload for any fix build**

For every bug fix during beta:
1. Fix on main.
2. Bump build number only (version stays `1.0.0` until submission).
3. Re-run Tasks 8.2 Steps 1–5.
4. Add the new build to the existing external group (no new Beta App Review is needed if the marketing/test metadata didn't change substantively).

- [ ] **Step 5: Close the beta after ≥7 days of stable use**

Criteria to close:
- ≥1 week elapsed since the first external invite
- ≥1 confirmed iPhone SE tester and ≥1 confirmed iPad tester
- No unresolved blockers in the feedback log

Commit the final build's version marker:
```bash
git tag v1.0.0-rc
git push --tags
```
(Confirm with user before pushing tags if this is the first time the repo has been pushed to a remote.)

---

## Task 8.5 — Screenshots

**Files:**
- Create: `docs/ios/screenshots/README.md`
- Create: `docs/ios/screenshots/iphone-6.7/*.png` (uploaded to ASC, not committed in bulk — see note)
- Create: `docs/ios/screenshots/iphone-6.1/*.png`
- Create: `docs/ios/screenshots/ipad-12.9/*.png`
- Create: `docs/ios/screenshots/ipad-11/*.png`

> **Commit policy:** Commit the `README.md` and ONE representative PNG per size class to document the intended composition. The full 20+ PNG set is uploaded directly to App Store Connect and kept under `docs/ios/screenshots/` in `.gitignore` (or pushed to a separate asset branch) — the binary weight is not worth bloating the main history.

- [ ] **Step 1: Decide the 5 screenshot slots (same composition across all 4 size classes)**

1. Keyboard in Messages with the IPA popover open over `a` showing `a æ ɑ`
2. Keyboard in Notes with `θ` just inserted (visible in the document)
3. Setup tab (clean, before the "I've done this" confirmation)
4. Reference tab (a symbol mid-copy, toast visible)
5. About tab

- [ ] **Step 2: Capture on the required simulators**

Required sizes (spec §9.7):

| Class | Simulator device | Resolution |
|---|---|---|
| iPhone 6.7" | iPhone 15 Pro Max | 1290 × 2796 |
| iPhone 6.1" | iPhone 15 | 1179 × 2556 |
| iPad 12.9" | iPad Pro (12.9-inch, 6th gen) | 2048 × 2732 |
| iPad 11" | iPad Pro (11-inch, 4th gen) | 1668 × 2388 |

For each, boot the simulator, install the TestFlight build, walk through the 5 flows above, and use `⌘ + S` to save PNGs. Save into the matching subdirectory.

- [ ] **Step 3: Write the screenshots README**

Create `docs/ios/screenshots/README.md`:

```markdown
# App Store screenshots — IPA Keyboard iOS

Five screenshots per size class; identical composition across classes.

| # | Scene | Notes |
|---|---|---|
| 1 | Keyboard in Messages, long-press on `a` | Popover visible; blue dot on `a` |
| 2 | Keyboard in Notes, `θ` in document | Document shows ≥ one prior IPA char for context |
| 3 | Container app: Setup tab | Clean state; "I've done this" visible |
| 4 | Container app: Reference tab | Toast mid-appearance over row `t` / `θ` |
| 5 | Container app: About tab | Version string `1.0.0 (1)` or current build |

Size classes:
- `iphone-6.7/` — iPhone 15 Pro Max
- `iphone-6.1/` — iPhone 15
- `ipad-12.9/` — iPad Pro 12.9" (6th gen)
- `ipad-11/` — iPad Pro 11" (4th gen)

Upload order in App Store Connect matches the # column above.
```

- [ ] **Step 4: Commit the documentation**

```bash
git add docs/ios/screenshots/README.md docs/ios/screenshots/iphone-6.7/01-keyboard-messages-popover.png
git commit -m "docs(ios): screenshot plan + representative sample"
```

---

## Task 8.6 — App Store Connect metadata

**Files:**
- Reference: `docs/ios/review-notes.md` (paste into the Review Notes field)
- Reference: `docs/ios/submission-checklist.md` (Phase 7)

- [ ] **Step 1: App Information**

App Store Connect → App Information:

| Field | Value |
|---|---|
| Category — Primary | Utilities |
| Category — Secondary | Education |
| Content Rights | "No, it does not contain, show, or access third-party content." |
| Age Rating | 4+ (answer "No" or "None" to every questionnaire entry) |
| Bundle ID | `com.minhphan.ipa-keyboard-ios` |

- [ ] **Step 2: Pricing and Availability**

- Price Schedule → Free → base territory USA → all territories
- Availability: All countries/regions (there is no localized content to gate)

- [ ] **Step 3: App Privacy (must match `PrivacyInfo.xcprivacy`)**

Privacy → Get Started → answer:
- Data Used to Track You → **None**
- Data Linked to You → **None**
- Data Not Linked to You → **None**

If App Store Connect pushes back with "UserDefaults stores user settings — please declare", the answer is still **None** for all three buckets because settings are device-local and do not leave the app. The privacy manifest's `CA92.1` declaration is separate from the privacy-label questionnaire.

- [ ] **Step 4: Version information (1.0.0)**

Version 1.0 page (populate each field exactly):

- **Promotional Text** (170 char limit):
  > Type IPA symbols anywhere on iOS. Long-press the dotted letters for phonetic variants. Fully offline — no Full Access, no accounts, no data collection.

- **Description** (4000 char limit):
  ```
  IPA Keyboard is an iOS keyboard for typing International Phonetic Alphabet symbols, built for linguistics students, phoneticians, language learners, and anyone who needs IPA symbols in daily work.

  HOW IT WORKS
  Install the app, add IPA Keyboard in Settings, then switch to it with the 🌐 globe key in any app. Tap letters normally for a–z. Long-press any of the dotted letters (a, e, i, o, u, t, s, d, c, n, z) to pick an IPA variant — the same gesture you already know from the built-in iOS é/è popover.

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

- **Keywords** (100 char limit, comma-separated):
  `IPA,phonetic,linguistics,keyboard,phonology,transcription,symbol,unicode,alphabet,speech`

- **Support URL**: your GitHub or project site (e.g. `https://github.com/minhphan/ipa-keyboard`)
- **Marketing URL**: same as Support URL for v1 (or leave blank)
- **Privacy Policy URL**: a hosted copy of the single-paragraph policy stating "IPA Keyboard does not collect, store, or transmit any personal data. It requires no network and has no accounts."

- [ ] **Step 5: Build selection**

In the Version 1.0 page → Build → "+" → select the TestFlight build that finished the external beta.

Expected: build appears with a green checkmark, Export Compliance already resolved.

- [ ] **Step 6: Screenshots upload**

Upload to each size class:
- 6.7" Display → 5 PNGs
- 6.1" Display (optional on newer ASC — iOS will reuse 6.7" if missing; spec still requires capturing them, upload them)
- 12.9" iPad Display → 5 PNGs
- 11" iPad Display (optional; upload to be safe)

No App Previews (videos) for v1.

- [ ] **Step 7: Review notes & contact**

Paste `docs/ios/review-notes.md` verbatim into App Review Information → Notes. Fill the contact fields with your name, email, and phone. Demo account: **leave blank** (no sign-in).

---

## Task 8.7 — Final submission

**Files:**
- No code changes in this task.

- [ ] **Step 1: Run the submission checklist end-to-end**

Open `docs/ios/submission-checklist.md` (from Phase 7) and confirm every box is checked. If anything is still open, resolve it now.

- [ ] **Step 2: Run preflight one last time**

```bash
cd ios
./Scripts/preflight.sh
```
Expected: all 8 guards OK. This is the last automated gate before we hand the build to Apple.

- [ ] **Step 3: Submit for App Review**

App Store Connect → Version 1.0 page → "Add for Review" → answer the pre-submission questions:
- Export Compliance → "No" to encryption
- Content Rights → already set
- Advertising Identifier → "No" (we don't use IDFA)

→ "Submit to App Review".

Expected: status changes to "Waiting for Review" within minutes.

- [ ] **Step 4: Wait for the review verdict**

Typical turnaround: 24–72h. While waiting, do NOT:
- Withdraw the submission unless the issue is severe (resubmitting resets the queue)
- Push new TestFlight builds that change the version/build numbers referenced in the submission
- Modify any metadata that says "Editable while In Review" is **No** in ASC

Possible outcomes:
- **Approved** → proceed to Step 5.
- **Rejected** → read the Resolution Center message carefully. Common rejections:
  - "Keyboard extensions must provide a meaningful purpose beyond what is already provided by the standard keyboard." Response: cite the IPA symbol set + link to the Reference tab.
  - "Your app's privacy label is inconsistent with the privacy manifest." Response: re-check §9.4 + Task 8.6 Step 3.
  - "Support URL does not resolve." Response: host the page and resubmit.

For each rejection, log the exchange in `docs/ios/submission-log.md` (create if missing), fix the root cause, and resubmit the same build if no code change is needed, or archive a new build if one is.

- [ ] **Step 5: Release**

On Approved → release options:
- **Manually release this version** (recommended for v1 — lets you verify the App Store page before it goes live)
- Automatically release = fine if you're comfortable

Click "Release This Version" when ready. Expected: live on the App Store within 2–24h.

- [ ] **Step 6: Tag and commit**

```bash
git tag v1.0.0
git push --tags    # confirm with user if pushing to remote for the first time
```

- [ ] **Step 7: Close out the plan**

Tick Phase 8 in `ios/PLAN.md`:

```markdown
- [x] Phase 8 — TestFlight + submission
```

And, if every other phase box is also ticked, the iOS sub-project is done.

Commit:
```bash
git add ios/PLAN.md
git commit -m "docs(ios): mark Phase 8 complete — v1.0.0 shipped"
```

---

## Phase 8 done when

- [ ] App Store Connect record created with the correct bundle ID
- [ ] Both bundle IDs registered in the Developer portal with zero capabilities
- [ ] Distribution-signed archive uploaded; Export Compliance resolved
- [ ] Internal TestFlight smoke test passed on iPhone + iPad
- [ ] External TestFlight beta completed (≥1 week, ≥1 iPhone SE tester, ≥1 iPad tester, no blockers outstanding)
- [ ] Screenshots captured for all 4 size classes; ASC upload matches `docs/ios/screenshots/README.md`
- [ ] Metadata populated exactly per Task 8.6
- [ ] Privacy labels = "None" across all three buckets
- [ ] Review notes pasted verbatim from `docs/ios/review-notes.md`
- [ ] Preflight green on the submission build
- [ ] Submission status reaches "Approved"
- [ ] Version released (manual or automatic) and live on the App Store
- [ ] `v1.0.0` tag pushed; `ios/PLAN.md` Phase 8 box ticked
