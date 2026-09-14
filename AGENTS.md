# Kvil development

Keep the native, feature-first architecture consistent with the sibling Paeonia and Tidex projects. Prefer SwiftUI, Observation, initializer injection, and the standard Apple frameworks. No third-party dependency or generic framework is needed for the MVP.

The schedule engine is shared across every surface. Never add manual start/stop controls, completed-fasting claims, adherence scores, or a closing countdown without an explicit product decision. Reflections and weight never belong in the iCloud schedule payload.

Use semantic colors and components in `ios/SharedUI`. Use only Xcode-generated `LocalizedStringResource` symbols, such as `Text(.cancel)` and `String(localized: .saveFailed)`. Do not add a custom localization wrapper or symbol generator. Add English and Norwegian catalog translations together with translator context using `scripts/xcstrings-set`, then run `python3 scripts/validate-localization.py`. Translation through `bun run localize` is a separate, explicitly requested step; do not run it during builds, tests, or commits. Scenario storage must stay isolated from real integrations, and scenario code must remain Debug-only.

Native App Intents metadata is the narrow exception: Xcode's metadata extractor requires static `LocalizedStringResource` initializers for intent titles, descriptions, and shortcut short titles. Use existing catalog keys and their English defaults there. Runtime UI and intent dialogs still use generated symbols; shortcut invocation phrases use Apple's native `AppShortcuts` catalog.

Use the root build/test wrappers. Verify behavior at date boundaries and persistence/sync trust boundaries. Inspect actual simulator/device layouts after visual changes. Report physical-device and App Store checks separately from simulator success. Preserve unrelated work; do not commit, push, upload, or submit unless requested. Never add a Co-Authored-By trailer.
