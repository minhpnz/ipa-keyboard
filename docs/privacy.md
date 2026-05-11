---
layout: default
title: Privacy Policy — IPA Typing Keyboard
---

# Privacy Policy

**Effective date:** May 11, 2026
**App:** IPA Typing Keyboard (iOS)

## Summary

**IPA Typing Keyboard does not collect, store, or transmit any personal data.
It works entirely offline. It has no accounts, no analytics, no third-party
SDKs, and no network access of any kind.**

## What we don't collect

We do not collect any of the following, because the app simply doesn't have
the capability:

- No keystrokes, typed text, or text-field contents
- No user identifiers (no device ID, advertising ID, or IDFA)
- No contact information (name, email, phone)
- No location data
- No usage analytics or telemetry
- No crash reports (Apple's built-in crash reporting may apply, controlled
  entirely by your iOS Settings → Privacy → Analytics)

## How the keyboard works

The keyboard extension runs in Apple's standard iOS sandbox with **Full
Access disabled** (`RequestsOpenAccess = NO` in the app's Info.plist).
This means:

- The keyboard cannot read what you type in other apps
- The keyboard cannot make network requests
- The keyboard cannot access the system clipboard, your contacts, your
  photos, or any other personal data outside what Apple's standard
  keyboard API provides

When you select an IPA variant from the long-press popover, the keyboard
inserts the character into the host app's text field via the standard
iOS `UITextDocumentProxy.insertText` API — exactly the same mechanism
Apple's built-in keyboard uses.

## Local settings

The companion app stores a small amount of user preference data on your
device using Apple's standard `UserDefaults` API. This data:

- Stays on your device — it is never uploaded anywhere
- Is removed when you delete the app
- Includes only: which setup steps you have completed, your accessibility
  preferences, and other app-local state

This is declared in our App Privacy Manifest under the standard
"User Defaults" required-reason category (CA92.1).

## Third-party services

**None.** The app contains no third-party SDKs, no analytics, no ad
networks, no cloud sync services, and no remote configuration.

## Children's privacy

The app is rated 4+ and contains no advertising, in-app purchases, or
external links to content. It is safe for use by children of any age.
Because we collect no personal data, no special protections under COPPA
or GDPR-K are necessary.

## Changes to this policy

We will update this page if the app's behavior changes. The "Effective
date" above will reflect the most recent revision.

## Contact

Questions about this policy? Open an issue at:

[https://github.com/minhpnz/ipa-keyboard/issues](https://github.com/minhpnz/ipa-keyboard/issues)

Or email: **minh.phan81299@gmail.com**

---

*IPA Typing Keyboard is offered free of charge. No monetization, no
accounts, no subscriptions.*
