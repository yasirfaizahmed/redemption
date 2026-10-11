## Install on Android

1. Download **`redemption-<version>-universal.apk`** below (works on every phone).
   `…-arm64-v8a.apk` is a smaller build for almost all phones from the last ~8 years;
   `…-armeabi-v7a.apk` is for older 32-bit devices.
2. Open it on your phone and allow **Install unknown apps** for your browser or file manager when asked.
3. Open **Redemption**, pick a template (or start from scratch), set your intention — and begin.

**Updating:** from v1.1.0 the app updates itself — *Settings → App updates* (or just wait for the
“Update ready” card). Older versions: install a newer APK straight over the old one. Your journeys,
logs and photos are kept.
Before any reinstall, turn on *Settings → Google Drive backup* (or use *Export full backup*) to be safe.

**Verify the download (optional):** compare with `SHA256SUMS.txt`, e.g. `sha256sum -c SHA256SUMS.txt`.

## What you get

- Track anything with 13 input types — yes/no, choices with per-option credit, time, duration,
  counter, numbers, ratings, notes with tap-to-add suggestions, photos and files.
- One-tap logging on a daily timeline, with planned times, weekday schedules and reminders.
- A dashboard you design: journey ring (day X of 90), streaks, quick strips such as the five daily prayers,
  tracker rings, journey heat-map, trend charts, rewiring phase and your intention.
- Insights per day and per tracker, ZIP backup/restore with photos and CSV export.
- Optional automatic backup to a hidden folder in your own Google Drive — reinstall and pick up
  where you left off. Needs a one-time Google Cloud setup: see `docs/google-drive-setup.md`.
- Private by design: nothing leaves your phone unless you turn on Drive backup or export it.

> Signed with the project's shared development key. The `.aab` is for Google Play once a
> production upload key is configured (see README → Signing).
