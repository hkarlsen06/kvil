# Kvil development

Keep the native, feature-first architecture consistent with the sibling Paeonia and Tidex projects. Prefer SwiftUI, Observation, initializer injection, and the standard Apple frameworks. No third-party dependency or generic framework is needed for the MVP.

The schedule engine is shared across every surface. Never add manual start/stop controls, completed-fasting claims, adherence scores, or a closing countdown without an explicit product decision. Reflections and weight never belong in the iCloud schedule payload.

Use semantic colors and components in `ios/SharedUI`. Add English and Norwegian catalog translations together, then run `python3 scripts/localize.py`. Scenario storage must stay isolated from real integrations, and scenario code must remain Debug-only.

Use the root build/test wrappers. Verify behavior at date boundaries and persistence/sync trust boundaries. Inspect actual simulator/device layouts after visual changes. Report physical-device and App Store checks separately from simulator success. Preserve unrelated work; do not commit, push, upload, or submit unless requested. Never add a Co-Authored-By trailer.
