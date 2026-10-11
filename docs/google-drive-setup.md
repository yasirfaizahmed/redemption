# Google Drive backup — one-time setup

Redemption backs up to a **hidden app folder** in the user's own Google Drive
(`appDataFolder`, scope `drive.appdata`). Only Redemption can see these files; they
don't show up in the Drive file list and can't touch any of the user's other files.

Google only gives Drive access to apps registered in a Google Cloud project. The app
uses Google's *authorization-only* Android flow, so **there is no client ID or secret
in the source code** — Google recognises the APK by its **package name + signing
certificate (SHA-1)**. You register those once; no rebuild is needed afterwards.

Until this is done, *Connect* in the app shows “developer error 10”.

## Steps (≈10 minutes)

1. Open <https://console.cloud.google.com/> and create a project, e.g. **Redemption**.
2. **APIs & Services → Library →** search **Google Drive API → Enable**.
3. **Google Auth Platform → Branding** (the OAuth consent screen): app name
   *Redemption*, your email as support and developer contact. Audience: **External**.
4. **Google Auth Platform → Data Access → Add or remove scopes**: add
   `https://www.googleapis.com/auth/drive.appdata` and save.
5. **Google Auth Platform → Audience**, either:
   - add every Google account that will use the app under **Test users** (simplest for
     yourself and family), or
   - **Publish app** so anyone can connect. Google may show an “unverified app” screen
     until the app is verified — tap *Advanced → Continue*.
6. **Google Auth Platform → Clients → Create client**:
   - Application type: **Android**
   - Package name: `io.github.yasirfaizahmed.redemption`
   - SHA-1 certificate fingerprint of the key that signs your APK. For the APKs on the
     Releases page (signed with the shared dev key in `android/app/dev.keystore`):

     ```
     2E:E2:7F:36:DC:20:D3:F1:DF:65:1A:04:BF:5C:03:7D:C8:87:0D:5A
     ```

   - Create. There is nothing to download.
7. On the phone: **Settings → Google Drive backup → Connect**, choose your account and
   allow access. The first backup runs immediately.

It can take a few minutes after creating the client before Google accepts it.

### Using your own signing key

If CI signs with your own key (the `ANDROID_KEYSTORE_*` secrets, see README → Signing),
add a second Android client with that key's SHA-1:

```sh
keytool -list -v -keystore upload.jks -alias <your-alias> | grep SHA1
```

Apps installed from Google Play are re-signed by Play: add the **App signing key**
SHA-1 from Play Console → *Setup → App signing* as well.

## How backups work

- **When:** a couple of minutes after you change something, when the app goes to the
  background with unsaved changes, and on start-up if the last backup is over 12 hours
  old. *Back up now* runs one on demand.
- **What:** the same ZIP as *Export full backup* — journeys, trackers, entries,
  dashboard, settings and photos/files.
- **Versions:** one snapshot per phone per day (updated in place during the day). The
  10 newest are kept, plus always the newest snapshot of every other phone, so a new
  phone can never prune away the last backup of the old one.
- **Safety:** an empty app is never uploaded, so a fresh install can't overwrite a good
  backup before you restore it.
- **Restore:** on a fresh install tap **Restore from Google Drive** on the welcome
  screen; otherwise *Settings → Google Drive backup → Restore from Google Drive*. A
  restore replaces everything on the phone with the chosen snapshot.

To see or delete the hidden backups: drive.google.com → ⚙ **Settings → Manage apps →
Redemption → Options → Delete hidden app data**.

## Troubleshooting

| What you see | Fix |
|---|---|
| “developer error 10” | The Android client is missing, or its package name / SHA-1 doesn't match the installed APK. |
| “Access blocked” / “access_denied” | Add the account as a test user (step 5) or publish the app. |
| “Google Drive API has not been used in project …” | Enable the Drive API (step 2). |
| “Google access expired — Reconnect” | Tap *Reconnect*. In *Testing* mode Google can expire grants after about a week; publishing the app avoids this. |
| “Your Google Drive storage is full” | Free up space in the Google account. |

*Settings → Diagnostics* shows the time of the last backup, and *Share logs* includes
the `DriveSync` / `DriveBackup` / `GoogleDriveAuth` log lines.

## iOS

iOS needs an **iOS** OAuth client (bundle id) in the same project, its reversed client
id added as a URL scheme in `ios/Runner/Info.plist`, and the build run with
`--dart-define=GOOGLE_IOS_CLIENT_ID=<client id>`. Without it the Drive section shows
“Not available on this device”.
