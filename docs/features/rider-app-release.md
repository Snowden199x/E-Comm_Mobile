# Rider app release and distribution

**Status:** Android release build produced and distributed through GitHub Releases. Google Play is not set up yet.
**Scope:** `vendo_rider/` Android. iOS is configured for icons only and is not part of this release.

## App identity

| Field | Value | Notes |
| --- | --- | --- |
| Application ID / namespace | `vendoph.rider` | Permanent. Changing it later makes a different app in Play and on phones. |
| Launcher label | Vendo Rider | Was "Vendo Xpress". |
| Version | `1.0.0+2` in `pubspec.yaml` | `versionCode` is the `+2`; increment it on every release. |
| Launcher icon | `assets/images/app_icon.png` + `app_icon_foreground.png` | Generated from the web brand icon `E-Comm_Web/public/images/logo/vendo-icon.png` and applied with `flutter_launcher_icons` (legacy + adaptive, white background). |
| Min / target SDK | 24 / 36 | Android 7.0 and newer. `flutter build` fails without Android SDK 36 installed. |

`MainActivity.kt` lives at `android/app/src/main/kotlin/vendoph/rider/MainActivity.kt` and declares `package vendoph.rider`.

## Signing

- The upload keystore is `android/app/upload-keystore.jks` with `android/key.properties` (`storeFile=upload-keystore.jks`, alias `vendo-rider`).
- Both files are excluded by `vendo_rider/android/.gitignore` (`key.properties`, `**/*.jks`, `**/*.keystore`). **Never commit them.**
- The certificate is `CN=Vendo Rider`; releases are signed with it, not with the debug key. Confirm with:
  ```bash
  $ANDROID_SDK/build-tools/36.0.0/apksigner verify --print-certs <apk>
  ```
- Back up the `.jks` and its passwords offline. Losing them means no update path for installed users, unless Play App Signing is used later.
- The same key can be the Play upload key. If Play App Signing is enabled, Play re-signs with its own key and the app-store SHA-1 changes.
- Google Sign-In on Android needs the release key registered. Current release certificate fingerprints:
  - SHA-1 `C9:86:6E:DA:E3:7E:3B:7C:ED:AE:19:2B:AC:A1:77:46:DE:32:4F:5A`
  - SHA-256 `54:42:5A:6B:D5:8F:55:2D:49:37:DA:49:90:F8:03:CD:72:95:67:F5:7E:C1:92:70:3D:29:0D:82:D9:DF:10:2B`
  Until they are added to the Google Cloud OAuth Android client, Google sign-in fails on release builds; email/password works.

## Build environment

- Flutter 3.47.9 (stable), Android SDK at `/home/Snowden/android-sdk` with platform 36 and build-tools 36.0.0, CMake 3.22.1 installed by the build.
- Gradle wrapper is 8.14 and does **not** support the system Java 25. Use a JDK 21 for Android builds. A JDK 21 tarball can live in `vendo_rider/.tooling/` (gitignored):
  ```bash
  export JAVA_HOME="$PWD/.tooling/jdk-21.0.13+9"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```

## Build commands

```bash
cd vendo_rider

# One file that installs on any Android phone (largest download)
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk

# Smaller per-ABI files
flutter build apk --release --split-per-abi
# → app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk
```

Sizes from the 10 November 2026 build (ML Kit OCR + barcode scanner are the bulk):

| File | Size | Use |
| --- | --- | --- |
| `app-release.apk` / `vendo-rider.apk` | 107 MB | Universal; works on 32-bit and 64-bit phones |
| `app-arm64-v8a-release.apk` | 46.6 MB | Almost all phones from the last several years |
| `app-armeabi-v7a-release.apk` | 38.1 MB | Older 32-bit phones |
| `app-x86_64-release.apk` | 49.6 MB | Emulators only |

Universal APK SHA-256 (build `1.0.0+2`): `f24bba197773c1318b0a3ad6490228aa2b388aa7f7a0a9841d19eac2581826d5`.

`isMinifyEnabled` and `isShrinkResources` are off, so R8 cannot strip anything the scanner or OCR needs. Turning them on is a future size optimisation that needs device testing.

## Distribution: GitHub Releases

The web landing page button and QR open `https://vendo-ph.app/logistics/get-the-app`, which redirects to:

```
https://github.com/Snowden199x/E-Comm_Mobile/releases/latest/download/vendo-rider.apk
```

That URL always serves the newest release, so **the asset must keep the exact name `vendo-rider.apk`** and each release must be published (not draft, not pre-release).

Release steps:

1. Bump `version: x.y.z+N` in `vendo_rider/pubspec.yaml` (`N` must increase).
2. Build the APK with the JDK 21 environment above.
3. Copy `app-release.apk` to `vendo-rider.apk`.
4. Create a release at <https://github.com/Snowden199x/E-Comm_Mobile/releases/new> with tag `rider-vX.Y.Z`, title `Vendo Rider X.Y.Z`, and attach `vendo-rider.apk` (optionally the arm64 and armeabi-v7a files under their own names).
5. Publish, then open the landing page on a phone and confirm the download starts. Users must allow installing from the browser once.

Notes:

- The repository must stay **public** for anonymous downloads. A private repository would require the reader to sign in to GitHub.
- Direct APKs do not auto-update; riders download each new version again until the app is in Play.
- To move to Play later, change the web app's `RIDER_APP_DOWNLOAD_URL` (or `config/services.php`) to the Play listing. No new QR is needed.

## Login behaviour

The rider sign-in form accepts both account types:

- Approved Rider (`role = courier`, approved, active center) → rider dashboard.
- Any other account gets a `401`, then the app tries the Transport Driver endpoint with the same credentials. An approved driver opens the driver trips screen; a pending or rejected driver sees the server's reason.

The separate "Transport Driver" link on the sign-in screen still works and goes straight to that endpoint.

## Known gaps

- Google Play is not set up ($25 one-time; personal accounts need a 12-tester / 14-day closed test first; organization accounts with a D-U-N-S number are exempt).
- Google sign-in is not enabled for the release certificate until its SHA-1 is registered.
- No auto-update, no crash reporting, no staged rollout.
- iOS build is untested; only icons were regenerated.
- The 107 MB universal APK is heavy on mobile data; prefer the 46.6 MB arm64 file when the phone is known to be 64-bit.
