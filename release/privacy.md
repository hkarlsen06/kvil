# Kvil Privacy Policy

Effective date: 15 September 2026

Kvil is developed by Hjalmar Karlsen. Questions about privacy or your data can be sent to [hjalmar@hkarlsen06.dev](mailto:hjalmar@hkarlsen06.dev).

## Data on your device

Kvil stores your eating schedule, optional daily reflections, settings, and manually entered weight measurements on your device. It uses protected local storage. The developer does not receive these records or operate a separate server for them.

Kvil excludes its local database and derived widget files from automatic device backup. You can export a backup from Settings and restore it later. Exported backups contain personal data. Keep them in a location you trust and delete copies you no longer need.

## iCloud schedule sync

When schedule sync is enabled, Kvil uses a private CloudKit database in your Apple Account. Your schedule includes weekly eating times, days off, dated changes and breaks, and the times recorded when you choose Start fast now or Break fast early. Previous schedule versions and change timestamps are retained to keep past plans consistent and merge changes made on different devices. Reflections, reflection meal times, notes, weight measurements, and Apple Health records are not included.

Kvil uses Apple's encrypted CloudKit fields to protect the schedule payload before it is sent to iCloud. Encryption-key protection and recovery follow Apple's account security settings, including Advanced Data Protection. The database is not shared with other users, and Kvil has no developer server that receives its contents.

When updating from a version that used iCloud key-value storage, Kvil transfers that schedule into the encrypted CloudKit record. It requests removal of the old value only after the encrypted copy is saved. Offline devices and older app versions can delay removal or recreate an older copy; keep Kvil updated on your devices.

Sync requires a working iCloud account and connection, and changes may take time to arrive. Turning sync off in Kvil Settings stops further synchronization but does not delete an existing cloud copy. If Kvil detects a different Apple Account or removal of its saved cloud schedule, it pauses sync until you enable it again. Your local schedule remains available.

## Apple Health

Apple Health integration is optional and limited to body weight. Connecting Health requests read and write authorization together; you choose what to allow in Apple's permission screen. Read access lets Kvil display the measurements Health makes available. If write access is granted, new Kvil measurements are saved to Health. You can turn off Save new weights to Health in Kvil Settings. Denied writes leave new measurements local. Kvil does not write imported measurements back to Health or use Health data for advertising, marketing, or third-party analytics.

You can disconnect Health in Kvil, or manage permissions in Apple's settings. Disconnecting stops future reads and writes. Existing Health records remain unless you delete them. Apple's Health synchronization, if enabled, is controlled by your Apple settings and is separate from Kvil's iCloud schedule settings.

## Widgets and Apple Watch

Kvil shares a limited copy of your eating schedule with its widgets and your paired Apple Watch using Apple's App Groups and WatchConnectivity. These copies include current schedule adjustments, but no reflection history or weight. Widgets, notifications, and Live Activities may reveal schedule information to anyone who can see your screen. You control their visibility through Apple's settings.

## Purchases

Apple processes the optional non-consumable purchase. Kvil uses Apple's signed transaction information to determine whether full history is unlocked. The developer does not receive your payment card details. Purchase restoration is available regardless of whether you currently have local records.

## Analytics and advertising

Kvil contains no advertising, third-party analytics, or tracking SDK. If you choose to share diagnostics with Apple, Apple's diagnostic settings apply. If you email support, the message and information you choose to provide are used to answer your request. Please do not send weight or reflection history unless you specifically want to include it.

## Export and deletion

Backup export, import, and local deletion are available without a purchase. Import replaces local records after confirmation and preserves that device's existing schedule-sync choice. Health, reminders, and Live Activities stay off after import until you enable them again.

Erasing Kvil data removes your local schedule, reflections, and Kvil weight entries and clears reminder/device state. When schedule sync is enabled, Kvil queues a cloud schedule reset; delivery requires an available account and connection. A reset marker remains so an offline device cannot simply restore an older schedule. Erasing locally while sync is off does not erase the existing cloud copy. Previously exported backups and records saved in Apple Health are not erased by this action. You can manage those copies separately.

Older reflections remain stored locally when they move beyond the free history view. A purchase unlocks the longer view; it is not required to export or delete your data.

## Audience and changes

Kvil is a planning tool intended for adults and does not provide medical advice. Material privacy changes will be reflected in an updated policy and app copy. Contact [hjalmar@hkarlsen06.dev](mailto:hjalmar@hkarlsen06.dev) with any privacy question.
