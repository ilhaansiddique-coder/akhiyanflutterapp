# Release & Distribution

Free OTA-ish APK distribution via Firebase App Distribution + GitHub
Actions. Every push to `main` builds a release APK and ships it to
testers in the `akhiyan-staff` group. They get an email + in-Firebase
notification; tapping "Update" installs the new APK over the old one
with no data loss.

## One-time setup

### 1. Firebase project (web console — ~3 min)

1. Sign in at https://console.firebase.google.com with **elsiddiue@gmail.com**
2. **Add project** → name `akhiyan-admin` → disable Google Analytics
   (not needed for App Distribution)
3. Inside the project, click the Android icon to add an app:
   - **Android package name**: `com.akhiyan.akhiyan_admin`
   - **App nickname**: `Akhiyan Admin`
   - Skip SHA-1 for now (only needed for OAuth / Firebase Auth)
4. Download `google-services.json` and save to
   `android/app/google-services.json` (this file is safe to commit;
   it's a public client identifier, not a secret)
5. Left nav → **Build → App Distribution** → **Get started**
6. Copy the **App ID** (looks like `1:NNN:android:abc123...`) — needed
   for the GitHub secret below

### 2. Firebase service account (web console — ~2 min)

GitHub Actions needs a service account to push releases.

1. Firebase Console → ⚙ icon (top left) → **Project settings**
2. **Service accounts** tab → **Generate new private key**
3. A JSON file downloads — open it and copy the **entire contents**
4. (The downloaded file should be deleted from disk after use; keep
   it only inside the GitHub secret.)

### 3. Tester group (web console — ~1 min)

1. App Distribution → **Testers & Groups** → **Groups** tab
2. **Add group** → name `akhiyan-staff` (must match exactly — the
   workflow uses this name)
3. Add tester emails (yours, anyone who should get builds)

### 4. GitHub secrets (~3 min)

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `FIREBASE_APP_ID` | The "1:NNN:android:..." string from step 1.6 |
| `FIREBASE_SERVICE_ACCOUNT` | Paste the entire service account JSON from step 2 |
| `ANDROID_KEYSTORE_BASE64` | (optional) `base64 -w0 release.keystore` output |
| `ANDROID_KEYSTORE_PASSWORD` | (optional) keystore password |
| `ANDROID_KEY_ALIAS` | (optional) key alias |
| `ANDROID_KEY_PASSWORD` | (optional) alias password |

Without the keystore secrets, builds use debug signing — fine for
first-iteration testing, but Android refuses to install over a
release-signed APK with a debug-signed one (and vice versa). Once
you ship a properly signed build, all future builds must use the
same keystore.

## Generating a release keystore (one-time, when ready to ship signed)

```bash
keytool -genkey -v -keystore release.keystore -alias akhiyan \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then base64-encode for the GitHub secret:

```bash
# Linux / macOS / Git Bash
base64 -w0 release.keystore > release.keystore.b64

# PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) > release.keystore.b64
```

**Keep `release.keystore` somewhere safe (1Password / encrypted USB).**
Losing it means losing the ability to update the app — Android requires
all updates to be signed by the same key.

## How updates reach testers

```
git push origin main
   │
   ▼
GitHub Actions: .github/workflows/release.yml
   │  flutter build apk --release
   ▼
Firebase App Distribution upload
   │  notifies group "akhiyan-staff"
   ▼
Tester gets email "New build available — Akhiyan Admin"
   │  taps install link
   ▼
APK downloads + installs (replaces previous version)
```

Build time end-to-end: ~3-5 minutes from push to email arriving.

## Triggering a release manually (skip a commit)

GitHub repo → **Actions → Release APK to Firebase App Distribution →
Run workflow → main → Run workflow**. Builds and ships from the latest
`main` commit without needing a new push.

## Alternative: Shorebird for true OTA (optional, future)

Firebase App Distribution still requires the user to tap "Install" for
each update. **Shorebird** lets you push *Dart code patches* that apply
silently on next app launch — no install prompt, no notification.
Free tier: 200,000 patch installs/month.

Limitations: only Dart code patches. Native Android changes, asset
changes, package upgrades still need a full APK rebuild + reinstall via
Firebase. So Shorebird complements Firebase rather than replacing it.

Set up later if/when daily Dart-only fixes become a pattern.

## Backend independence

This pipeline is independent of where the backend lives. Today the
APK calls the Coolify deploy at
`http://l10yo20jq5mhrg8b8nmp68cr.168.144.126.233.sslip.io/api/v1/m`
(default in `lib/config/env.dart`). When you migrate to Hostinger or
another VPS, only that URL changes — the Firebase distribution
mechanism is unchanged.
