# First-release decisions

Updated 16 September 2026 from the owner's explicit instructions. These decisions supersede earlier release-gate wording in the audit reports; historical findings and test results remain evidence of what was observed.

## Active engineering work

The remaining Settings/reminder clipping reports are resolved. Six focused Settings UI flows passed in dark mode on the iOS 27 iPhone 13 mini simulator: English, Norwegian, largest Norwegian text, largest-text reminder timing, reminder/Live Activities preferences, and weight/sync/navigation controls. The native audits retain all issue reporting. Final captures were inspected, including the full reminder value and the current section after text-size changes; a real menu interaction after the audit verifies usability. The two earlier Home audit cases remain accepted. [Current evidence](accessibility-remediation-verified.json). This is focused simulator validation, not a full-suite or App Review approval claim.

## iCloud

Keep the implemented encrypted private CloudKit schedule sync. The owner treats the classification question as a non-blocking item unless App Review raises it. No further architecture change or pre-review Apple consultation is required for this release. This is the owner's release decision, not a claim of Apple approval.

## Available-device coverage

The owner has one iPhone. Two-iPhone convergence is unverified and is not a release gate under this decision. Preserve the evidence from the physical single-iPhone CloudKit test and simulator tests. Other unperformed hardware, background-delivery and TestFlight checks remain unverified; do not describe them as passed.

## Distribution

Mainland China is excluded from the app and Full History purchase. Both have 174 available territories; the other regions are unchanged. [Live readback](china-availability-verified.json).

## Build delivery

Build uploads to App Store Connect and App Review submission belong to the owner. Agents must never upload app builds to App Store Connect. The owner will handle build selection and submission; agent work is limited to requested local development, validation and separately authorized metadata changes.

The earlier local archive/export `2449.6.4` predates the evening accessibility changes. It is retained as historical verification evidence and is not a build of the current working tree. No replacement archive or upload was made during this follow-up.

## Custom interval limit

The owner authorized a six-hour minimum eating window. The duration picker now offers 6–23 hours. New setup, weekly edits, today overrides, dragging and copy/paste enforce the minimum when saving changed windows; precise weekly editing still supports minutes, up to 23 hours 59 minutes. The existing 12:12, 14:10 and 16:8 presets remain, and 18:6 is available.

Older short windows remain readable from local storage, backups and sync. Editing another day does not force changes to them. Changing or re-enabling a short window requires at least six hours. Actual meal records and early-opening/closing adjustments retain their existing behavior.

The limit uses local clock times and retains the existing daylight-saving policy. It does not cap the actual fasting gap across differing daily start times or clock changes, and it is a product boundary rather than a medical safety guarantee.

Verification: 72 model tests and three UI flows passed on the iOS 27 iPhone 13 mini simulator, including the 5h59m/6h boundary, overnight edits, unchanged persistence after rejection, legacy backup/sync compatibility, copy/paste and daylight-saving behavior. After correcting a picker compiler warning, all nine window-editing tests and the picker/drag/save UI flow passed again with no warnings (build `2449.22.4`). Dark-mode menu and validation-message captures were inspected; English/Norwegian localization validation passed. These are local simulator checks, not App Review or two-device sync verification.
