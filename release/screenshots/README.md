# Store screenshots

These are unmodified dark-mode captures of Kvil's production SwiftUI views using fictional schedules and reflections, refreshed on 15 September 2026. English and Norwegian each have four iPhone images at 1320 × 2868 and one Watch image at 410 × 502. The eleventh image is the English purchase review screen, using Apple's local StoreKit test catalog at US $3.99.

`manifest.json` records each file, dimensions, SHA-256, appearance, capture time, build and source. All eleven final images were visually inspected and their dimensions and hashes verified. The iPhone simulator was explicitly set to dark appearance. The Watch uses the app's native dark palette; its background now fills the screen in both languages.

These files have not been uploaded to Apple. Replace the old sets alongside the next candidate, including adding the Norwegian welcome image. `../apple-media-verified.json` and `../photography-verified.json` are historical evidence for older captures; neither verifies delivery of this set.

The final iPhone capture test passed in `Kvil-test-1789437874-12844.xcresult`; the wrapper log is `build/app-review-dark-screenshots-final.log`. Watch captures use an isolated simulator and a fictional snapshot validated and round-tripped through the production schedule/storage code. Phone scenario integrations are disabled. No screenshot pixels were edited.

The iPhone images belong to the 6.9-inch display class in App Store Connect and were captured on iPhone 17 Pro Max. The Watch screenshots were captured on Ultra 2. Smaller-phone and largest-text checks are separate QA evidence under `build/`; three native accessibility audit failures remain documented in the remediation report. Screenshot-test success does not resolve those failures or replace physical-device/App Store verification.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) accept these dimensions. Apple accepted the iPhone captures in APP_IPHONE_67 (displayed as 6.9-inch in the current UI) and the Watch captures in APP_WATCH_ULTRA.
