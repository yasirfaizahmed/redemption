# Changelog

Every release's notes come from its section below: CI copies the section into
the GitHub release, and the app shows it under “What’s new” before updating.

## 1.8.0

- **Redemption's own wake-up alarm.** Tap a wake-up time after *Now* on Sleep
  time and the alarm is set inside Redemption. It rings at full volume, which
  the volume buttons can't lower, and covers the screen with a sum to solve
  (e.g. 38 × 17 + 469). It stops only when you get it right. Tap a set time
  again to cancel it.
- It keeps ringing if you close the app, and rings again after a restart, or
  when the app is next opened, if it was never solved.
- **Settings → Wake-up alarm:** how hard the sums are (medium, hard, very hard),
  how many in a row (1–5), a 15-second test alarm, and a checklist so nothing
  gets you out of it: notifications, showing over the lock screen, battery
  saving, and the optional **alarm guard**. Turn the guard on in Accessibility;
  while the alarm rings it closes the power menu, the uninstall dialog,
  Settings and other apps, and ignores the volume buttons.
- No app can stop a forced restart (holding the power button about 10 s); the
  alarm rings again once the phone is back on. Turn *Ring in Redemption* off to
  use your Clock app as before.

## 1.7.0

- **More achievements on each tile.** A journey-grid tile now fits up to six
  tiny emojis, in two rows under the day number.
- **Choose what the tiles show.** In *Customise dashboard → Journey grid*, or the
  sliders button on the Insights grid, tap each achievement on or off (🌟 🔥 🕌 🤲 🍽️ and every
  tracker's own emoji), set how many emojis fit on a tile (1–6), and choose
  whether a perfect day shows just 🌟. Tapping a day still lists everything it
  earned.
- **Colour the Home grid by any tracker, right on the card.** A *Colour by* pill
  above the grid switches between the daily score (with achievements) and any
  tracker, and remembers your choice.

## 1.6.0

- **Achievements on the journey grid.** Every day now carries tiny emojis for
  what it earned: 🌟 a perfect day, 🔥 a streak milestone (3, 7, 14, 21, 30,
  40… days), 🕌 every prayer in congregation (🤲 every prayer on time), 🍽️
  every meal on time, and a tracker's own emoji when its goal is met — 💪
  Workout, 🌅 Wake-up time, 🌙 Sleep time. A legend under the grid explains
  them, and tapping a day lists them in full.
- Pick any tracker's emoji, or turn it off, in the tracker editor
  (*Achievement emoji*).

## 1.5.0

- **Wake up fresh: alarm times on full sleep cycles.** Tap *Now* on “Sleep
  time” and Redemption shows when to wake up at the end of 1–6 full ~90-minute
  sleep cycles (in your local time; 5–6 cycles, 7½–9 h, are marked
  *Recommended*). Tap a time to set the alarm in your phone’s Clock app.
- Set how long you usually take to fall asleep (none, 10, 15, 20 or 30 min) and
  every time shifts with it. The same wake-up times show in the Sleep time sheet
  for today’s bedtime.
- Any time tracker can suggest wake-up times (tracker editor → *Suggest
  wake-up times*); trackers named like a bedtime do so by default.

## 1.4.0

- **Work from home? “Left office” switches itself off.** Answer “WFH or
  office?” with *Work from home* (or *Leave / holiday*) and “Left office” leaves
  the timeline for the day: it doesn’t count against your score, isn’t waiting
  in *Next up* and doesn’t send its reminder. It sits under “Not needed today”,
  so you can still log it if you want.
- Existing journeys: the dashboard offers to add this to your “Left office”.
  Past work-from-home days then leave it out of the score too, whether or not
  you logged it, so a few past scores can shift slightly.
- Any tracker can be *not needed on certain days* — pick a choice tracker and
  the answers that switch it off (tracker editor, under *Repeat on*).

## 1.3.0

- **Meals: on time earns the points, what you ate is just for your notes.**
  “Breakfast / Lunch / Dinner on time?” now ask “What did you eat?” in the same
  sheet. Writing what you ate earns nothing on its own — only *On time* does —
  and the timeline shows it next to the answer (e.g. “On time — Rice, dal”).
- Existing journeys: the dashboard offers to fold your separate Breakfast /
  Lunch / Dinner text trackers into the on-time checks. They stop counting from
  today (past days keep their score and their text), and what you wrote on days
  the checks already existed moves into their notes.
- Any Yes/No tracker with a comment can make it *just for information*
  (tracker editor).

## 1.2.0

- **Workout is now “Did you train?”.** One tap on ✓ logs *Trained* and earns the
  points; the sheet opens with a “What did you train?” comment box, and the
  timeline shows your comment next to the answer. Already using the app? The
  dashboard offers to switch your Workout over: what you wrote on earlier days
  becomes their comment, so nothing is lost and past scores stay the same.
- Any Yes/No tracker can ask for a comment (tracker editor → *Ask for a comment*).

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
