# iOS Submission Checklist

Re-run before every App Store submission. Each item must be ticked in the PR that produces the build.

- [ ] `RequestsOpenAccess = NO` in extension `Info.plist`
- [ ] `IsASCIICapable = YES` in extension `Info.plist`
- [ ] `PrivacyInfo.xcprivacy` present in both targets, declares `CA92.1` for `UserDefaults`
- [ ] No network / App Group / Full Access entitlements
- [ ] CI preflight green: codegen fresh, forbidden-APIs grep clean, extension size within 5% of baseline
- [ ] All unit + snapshot + UI tests green
- [ ] Manual checklist signed off (see `manual-test-checklist.md`)
- [ ] Apple privacy-report tool run against the built app; output matches the manifest
- [ ] TestFlight ≥1 week; ≥1 tester on iPhone SE, ≥1 on iPad; no blocking regressions
- [ ] Screenshots captured: iPhone 6.7" + 6.1"; iPad 12.9" + 11"
- [ ] App Store Connect: description, keywords, support URL, privacy policy URL populated
- [ ] Distribution-signed build uploaded via Transporter or `xcrun altool`
