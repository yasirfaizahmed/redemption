# Changelog

Every release's notes come from its section below: CI copies the section into
the GitHub release, and the app shows it under “What’s new” before updating.

## 1.1.0

- **In-app updates.** Redemption now checks GitHub for new versions when you open
  it, downloads the right APK for your phone in the background, verifies its
  SHA-256 and hands it to Android's installer — one tap to update. Find it under
  *Settings → App updates* (check now, automatic checks, background download).
- **Google Drive backup.** Connect your Google account in *Settings → Google Drive
  backup* and your journeys, logs and photos are backed up automatically to a
  hidden folder in your own Drive. Reinstalled? Tap *Restore from Google Drive*
  on the welcome screen. Needs a one-time Google Cloud setup
  (see `docs/google-drive-setup.md`).
- **Office days (Redemption template).** When *WFH or office?* is *Office*, Dhuhr,
  Asr and Maghrib show “Office day — no masjid”, the congregation button steps
  aside from the one-tap row and praying on time earns full marks. Any choice
  tracker can now be *different on certain days* (tracker editor → Goal).
- **Meals on time.** “Breakfast / Lunch / Dinner on time?” checks that count
  towards the daily score. Existing journeys get a one-tap offer on the
  dashboard to add both improvements (the meal checks start today, so past
  days keep their score).
- **Import data from any version.** *Import a backup file* on the welcome screen
  (or *Settings → Import data*) takes over a ZIP/JSON backup made by any
  version, including v1.0.0 — or simply install this update over v1.0.0: all
  data is kept.
- **Yes/No trackers show the win.** When “Skipped” is the win (quitting a habit),
  the one-tap button logs “Skipped” and shows a green ✗; when “Done” is the win
  it's a green ✓. Red only when the answer isn't the win.

## 1.0.0

- First release: fully customisable daily trackers (13 input types), a
  dashboard you design, the 90-day journey ring, insights, reminders, ZIP/CSV
  backup and the Redemption template.
