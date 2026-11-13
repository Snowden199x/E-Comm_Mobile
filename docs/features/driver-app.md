# Vendo Driver app

**Status:** Registration, application status, sign-in, session restore, password reset, the trip board (`GET /trips`, load scan, depart, arrive), the accrued earnings ledger (`GET /earnings`), driver notifications and completed-trip history are connected to the web API.
**Updated:** 13 November 2026

`vendo_driver/` is the Flutter app for the Transport Driver — the person in charge of the trucks and vans that move parcels between Stations and Province Hubs. It uses the same Vendo palette and Material 3 language as the Rider app, but it has its own screens and a separate bottom navigation widget.

## Scope

- The driver never collects or carries COD cash. A COD parcel is just a parcel. The manifest shows tracking numbers and statuses only: no addresses, buyer details, prices or COD amounts.
- Opening a manifest does not prove that every parcel arrived. Station scans are the proof of receipt. Dispatch requires every origin scan; closing the trip requires every destination scan.
- Notifications and completed-trip history are live. Container scanning, incident/discrepancy reports and salary are later; the places that mention them are labelled **Later** and are not functional.

## Registration and approval

Registration is a four-step form copied from the Rider registration: the same Prune gradient header, step card and progress bar, labelled fields with hint text inside the box, upload rows, and the Back / Next bar. The steps are **Personal Info**, **Address & Contact**, **Vehicle & Licence**, and **Apply & Review**.

The driver must choose where to apply:

| Apply to | Reviewed by | What it means |
| --- | --- | --- |
| Station Hub only | The chosen Station Hub | The driver works station to station. |
| Province Hub only | The chosen Province Hub | The driver works hub to hub trips and is linked to the Station Hub where they live. |
| Both | The Province Hub only | The Station Hub can see the details but does not approve. The driver is also linked to the Station Hub where they live. |

The app sends `apply_to`, the chosen hub and the PSGC province / city / barangay codes to `POST /api/v1/transport-drivers/register`. For Province Hub and Both, the server links the driver to the Station Hub that covers their municipality, or the nearest one, so the app only previews the match: it says either "You will be linked to <hub> because it covers <city>" or "No Station Hub in <city>. The nearest one in your area will be used."

When the address changes, the Apply step re-reads the selected province and city, so the preview follows the address the driver actually entered.

Documents: the licence is photographed or picked from the gallery and uploaded privately as `drivers_license`. The licence is the driver's identity document, so no separate Valid ID is asked for; older installs may still send `valid_id` and the API accepts it as optional.

Email verification uses the same sheet as the Rider and Buyer registrations: the Email label has a **Verify** link that opens a bottom sheet with six digit boxes and sends the code straight away (`POST /email/otp/send`). The boxes move on their own, the code is checked as soon as all six digits are in (`POST /email/otp/verify`), and **Resend Code** is available. On success the email field shows a green *Verified* mark and the returned `verification_token` is sent with the application. Changing the email clears it, and Step 1 does not advance until the email is verified.

After submitting, the success sheet names the hub that reviews the application and the Station Hub the driver is linked to, then returns to sign-in.

## Sign in and application status

Sign-in calls `POST /api/v1/transport-drivers/login` with the email and password and keeps the token in secure storage. **Continue with Google** (13 November 2026) sends the Google ID token from `google_sign_in` to `POST /api/v1/transport-drivers/google`; the API verifies it and applies the same role, approval and hub checks, returning the same session payload, so an approved driver opens the trip board and a pending application shows the same waiting notice. Google does not replace the password of an unknown email: the API answers that no driver application uses that Google account, and the app says to apply first. `lib/core/config/google_auth_config.dart` defaults to the same public web client ID the website uses (also accepted through the web's `GOOGLE_ALLOWED_CLIENT_IDS`) and still accepts `--dart-define=GOOGLE_WEB_CLIENT_ID=...` for another project. The Android OAuth client for package `com.example.vendo_driver` with this build's signing SHA-1 must exist in that project, or Google rejects the request before the app sees a token. Google sign-in is unavailable on Windows/Linux desktop. Two states are explained instead of a generic failure:

- **Waiting for approval** — the server answers `403` with the reviewing hub, so the screen says the application is still with that hub.
- **Rejected** — the screen shows the reviewer's reason.

**Check application status** opens a sheet that asks for the email and reads `POST /api/v1/transport-drivers/application-status`. It shows the decision, the apply scope, the linked Station Hub and the reviewer, so an applicant can check the decision without a password.

Signing out revokes the token and clears the stored session.

### Sign-in layout

The screen follows the Rider app's sign-in: a prune gradient header that names *Vendo Xpress* over the animated background (drifting dots, rings, stars and wind streaks), and a white rounded card that slides up over it. The header picture is a box truck drawn with `CustomPaint` — body, cab, driver silhouette, headlight glow and spoked wheels — instead of the Rider's motorcycle. The truck glides up into the header after the screen opens and the welcome text fades in behind it. Everything below stays the same: email and password fields, *Forgot password?*, *Sign in*, the pending/rejected notice, *Check application status*, and the registration link.

### Restoring a session

The app opens on [`driver_start_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_start_screen.dart). With no stored token it goes straight to sign-in. With a token it calls `GET /api/v1/transport-drivers/me` first:

| Answer | What happens |
| --- | --- |
| 200 | The returned profile replaces the placeholder one and the shell opens. |
| 401 | The token is cleared and sign-in opens, so a revoked token, suspension or expired licence never reopens a stale session. |
| Network failure | The last profile the web returned is used, so a driver on a weak connection is not forced to type a password again. With nothing stored, sign-in opens. |

The profile the API returns is what the Profile tab shows: name, email, mobile, licence number and expiry, vehicle and plate, Province Hub, the linked Station Hub, and the *Applied to* scope. The placeholder name is only visible before the first successful sign-in.

### Password recovery

**Forgot password?** on the sign-in screen opens [`forgot_password_screen.dart`](../../vendo_driver/lib/features/auth/screens/forgot_password_screen.dart), a three-step flow: email, the six-digit code the web emails, then the new password twice. It calls `POST /api/v1/transport-drivers/password/otp/send`, `/password/otp/verify` and `/password/reset`. The email already typed on the sign-in screen is carried over. A successful reset returns to sign-in with a confirmation, and every device signed in with the old password is signed out by the server. Recovery works for an applicant who is still waiting for approval: it changes the password only, not the decision.

## Screens

| Screen | File | What it does |
| --- | --- | --- |
| Start | [`driver_start_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_start_screen.dart) | Checks a saved token against `GET /me` and opens the shell or sign-in. |
| Sign in | [`driver_login_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_login_screen.dart) | API sign-in, pending/rejected states, application status sheet, forgot-password link, registration link. |
| Reset password | [`forgot_password_screen.dart`](../../vendo_driver/lib/features/auth/screens/forgot_password_screen.dart) | Three steps: email, six-digit code, new password twice. |
| Register | [`driver_register_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_register_screen.dart) | Four-step rider-style form: identity, email code, address (PSGC), vehicle and licence with uploads, Apply-to choice and review. Posts to the API. |
| Registration widgets | [`register_widgets.dart`](../../vendo_driver/lib/features/auth/widgets/register_widgets.dart) | Header, step bar, labelled fields, dropdowns, uploads, choice cards, review rows, bottom bar and success sheet. |
| API client | [`driver_api.dart`](../../vendo_driver/lib/core/api/driver_api.dart) | Hubs, PSGC locations, email code, register (multipart), login, session profile (`me`), password reset, application status, trips/scan/depart/arrive, earnings, notifications, trip history, token and profile storage. |
| Shell | [`driver_shell.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_shell.dart) | Five-tab `IndexedStack` shell. |
| Bottom navigation | [`driver_bottom_nav.dart`](../../vendo_driver/lib/features/dashboard/widgets/driver_bottom_nav.dart) | Separate navigation widget: Home, Trips, Manifest, Earnings, Profile. Same floating frosted-glass bar and sliding jelly pill as the Rider app; icons only, with the active icon turning white under the pill. |
| Home | [`driver_home_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_home_screen.dart) | Greeting with today's date and the vehicle/plate, notification bell with the unread count, tappable avatar that opens Profile, licence-expiry warning from 30 days out, sync strip, active trips and parcels onboard, quick actions (Manifest, Dispatch, Trip status), current trip card with scan progress, upcoming trips. Pull down to refresh trips and notifications. |
| Trips | [`driver_trips_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_trips_screen.dart) | All/Scheduled/In transit/Completed filters, trip cards and a **Trip history** button. |
| Trip history | [`driver_trip_history_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_history_screen.dart) | Closed trips from `GET /trips/history` with route, completion time, parcels and vehicle, newest first; loading, empty and error states with a sign-in action. |
| Notifications | [`driver_notifications_screen.dart`](../../vendo_driver/lib/features/notifications/screens/driver_notifications_screen.dart) | `GET /notifications` feed with unread marks, tap-to-read, mark-all-read, pull-to-refresh and honest empty/error states. |
| Manifest | [`driver_manifest_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_manifest_screen.dart) | Parcel list with tracking numbers and statuses, search, origin/received counts, trip selector when embedded. |
| Trip details | [`driver_trip_details_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_details_screen.dart) | Route rail, schedule, vehicle, distance, scan progress, manifest shortcut, and a **Scan parcels** action instead of a dispatch button. |
| Load scan | [`driver_scan_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_scan_screen.dart) | Camera reader plus a typed tracking number, single parcel or container labels that load several at once, the scanned count, a tick per parcel, and a **Confirm dispatch** that stays locked until the last parcel is scanned. |
| Dispatch confirmation | [`driver_dispatch_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_dispatch_screen.dart) | The last step after the load scan: readiness checklist (vehicle, license, origin scans) and a Depart action that shows the server-style reason when blocked. |
| Trip status | [`driver_trip_status_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_status_screen.dart) | In-transit timeline, ETA, parcels onboard, receiving count, handover action. |
| Destination handover | [`driver_handover_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_handover_screen.dart) | Receiving progress, pending tracking numbers, blocked reason, close-trip confirmation and a completed state that releases the vehicle. |
| Earnings | [`driver_earnings_screen.dart`](../../vendo_driver/lib/features/earnings/screens/driver_earnings_screen.dart) | Accrued per-stop shipping credits from `GET /earnings`, with pull-to-refresh, loading/empty/error states and a plain statement that accrued credits are not a salary or payout. |
| Profile | [`driver_profile_screen.dart`](../../vendo_driver/lib/features/profile/screens/driver_profile_screen.dart) | License and expiry, contact details, hub/company/vehicle, later features, sign out. |

Shared pieces live in [`vendo_theme.dart`](../../vendo_driver/lib/core/theme/vendo_theme.dart) (palette and Material theme), [`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) (trip board, profile, depart/arrive, accrued earnings, notifications, trip history) and [`driver_ui.dart`](../../vendo_driver/lib/features/shared/widgets/driver_ui.dart) (headers, cards, pills, route rail, bottom action bar).

## Navigation

The five tabs are Home, Trips, Manifest, Earnings and Profile. Manifest doubles as a tab and as a pushed screen: opened from a trip it shows that trip's manifest with a back button; opened from the tab it shows the current trip and lets the driver switch between non-completed trips.

The Home bell and the Trips **Trip history** button push their screens on top of the shell as well. Trip details, the load scan, dispatch confirmation, trip status and destination handover are pushed on top of the shell in that order. Closing a trip returns to the root shell, where the completed trip is gone from the current card and the next scheduled trip becomes current.

## Trips from the web

[`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) loads the board with `GET /api/v1/transport-drivers/trips`, which returns the driver's scheduled and in-transit trips, in-transit first:

| Field | Use in the app |
| --- | --- |
| `id`, `code` | The code is shown (`TRP-00042`); the id is what the depart and arrive calls address. |
| `status` | `scheduled` / `in_transit` / `completed`, mapped to the app's `TripStatus`. |
| `origin`, `destination` | Hub names with the municipality and province joined as the area line. |
| `scheduled_departure_at`, `expected_arrival_at`, `departed_at`, `arrived_at` | The schedule, ETA and timeline. A trip with no schedule falls back to when it actually left, then to now. |
| `vehicle` | Type and plate, falling back to the profile when the trip has no vehicle row. |
| `manifest` | Tracking numbers only, plus an `origin_scanned` / `destination_scanned` flag per parcel: no addresses, buyer details, prices or COD amounts. The flag is what ticks one parcel on the scan screen. |
| `origin_scanned`, `destination_scanned` | How many manifest parcels carry the origin departure scan and the destination arrival scan. These are the same scans the workflow checks before it lets a trip depart or close, so the progress bars show real counts. |

The board refreshes on three occasions: when the shell opens, when the driver pulls the Home list down, and when **Refresh** is tapped. The strip under the greeting says where the data came from — *Updated 2 min ago from Vendo*, *Loading the trips your hub assigned…*, or *These are sample trips* — and a failure shows a red notice with **Retry**. When the server answers `401` the stored session is cleared and the notice offers **Sign in**, which drops the token and opens the sign-in screen.

**Departing and arriving** call `POST /trips/{id}/depart` and `POST /trips/{id}/arrive` on live trips and keep the answer the server returns in place of the local trip, so the status, scans and ETA follow the web. A refusal (an unscanned parcel, an open exception, a dropped connection) is shown in the blocked sheet with the server's own reason. Local rules stay for the sample trips, which are only used before the first successful load and are kept on screen when the network is down.

### Scanning the load before dispatch

A scheduled trip no longer opens on a dispatch button. The trip details action and the Home quick action both open the **Load scan** screen, where the driver scans every parcel onto the truck:

1. The camera reads a parcel label (QR, Code 128, Code 39 or EAN-13) or a container label; a driver whose camera does not work types the tracking numbers and taps **Scan**.
2. Each scan sends every tracking number the label carries to `POST /api/v1/transport-drivers/trips/{id}/scan` with a fresh UUID `scan_key`. The server checks each parcel is on that trip's manifest and routed through the trip's origin hub, records them as the origin departure scans the depart check counts, and answers with the whole trip plus `recorded`, `duplicates`, `unknown` and `not_routed`, so the app takes the server's own count and per-parcel flags.
3. A repeated label is ignored for three seconds; a parcel that already carries the scan comes back as *already scanned*; a number that is not on the manifest, a parcel not routed through the origin hub, or a trip that already left are reported in the red answer under the field without failing the rest of the label.
4. **Confirm dispatch** stays disabled until every parcel is scanned. When the last one lands, the button opens the dispatch confirmation screen.

### Container labels

One scan can load several parcels, which is what a container label is for: the QR carries a list of tracking numbers instead of one. The app accepts the list separated by commas, semicolons, pipes, spaces or line breaks, optionally behind a scheme prefix (`VENDO-CONTAINER:` and similar), as a JSON list or as `{"tracking_numbers": [...]}`, and treats the trip's own QR code (`TRP-00042`) as the whole manifest. Codes shorter than five characters or containing anything other than letters, digits and dashes are ignored, duplicates are dropped, and at most 100 parcels travel in one request. Every parcel on the label is ticked at once, and the counter and progress bar jump by the number of parcels the label carried.

The server still enforces the same gate, so a trip cannot leave from another device or the web while a parcel is unscanned. Scans are also written as a `facility_scan_events` row attributed to the driver and a status note on the order, so the hub's parcel timeline shows who confirmed the load.

### Earnings from the web

The Earnings tab reads `GET /api/v1/transport-drivers/earnings` through [`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) (`refreshEarnings`), which the shell calls after sign-in and the screen calls on pull-to-refresh. The API's `summary.accrued_total` and `summary.hub_credits` fill the summary card, and each `earnings` row becomes one credit line: the order number, the hub name, the route position, the amount and the earned date. The app only displays the server amounts; it never computes or edits a credit, and closing a live trip reloads the ledger in the background so new credits appear without a manual pull. A rejected token shows the same **Sign in** action as Home, an empty ledger shows an empty state, and a network failure keeps the notice with **Retry** instead of inventing amounts. The legacy demo credits and the `LegacyCredit` model were removed, so no sample peso figures appear on this tab.

### Notifications and trip history

The bell in the Home header opens [`driver_notifications_screen.dart`](../../vendo_driver/lib/features/notifications/screens/driver_notifications_screen.dart), which reads `GET /api/v1/transport-drivers/notifications`. The same list is loaded when the shell opens and when Home is pulled down. The badge uses the server's `unread_count`, never a local guess: tapping a row calls `POST /notifications/{id}/read` and turns the row read at once, and **Mark all as read** calls `POST /notifications/read-all`. If either call fails the app puts the row back and resyncs, so the badge cannot drift from the web. A row that belongs to another account is refused with 404 by the API, and a rejected token shows the same **Sign in** action as the other tabs.

The **Trip history** button on the Trips screen opens [`driver_trip_history_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_history_screen.dart), which reads `GET /api/v1/transport-drivers/trips/history`: the driver's completed trips, newest first, with the route, completion time, parcel count and vehicle. It is a separate endpoint because the board only carries scheduled and in-transit trips, so a closed trip never disappears without a record. History loads when the screen opens and on pull-to-refresh.

### Sample trips

[`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) still seeds three trips for an offline first launch:

- **TRP-2406** — 12 of 12 parcels scanned at the Laguna Province Hub. Departing moves it to In Transit.
- **TRP-2407** — only 6 of 8 parcels scanned at Santa Cruz Station, so dispatch is deliberately blocked and its reason is shown.
- **TRP-2408** — 20 parcels, scheduled for tomorrow.

Only these sample trips get the **Demo: simulate station scans** action on the handover screen; it is hidden for a live trip, whose counts come from the station's real scans. The Home strip always labels the sample board so sample counts are never mistaken for real ones.

## Configuration

The API base comes from `VENDO_API_BASE_URL`:

```bash
flutter run --dart-define=VENDO_API_BASE_URL=http://<server>:8001
```

`DriverApi` appends `/api/v1/transport-drivers`, and also accepts a URL that already points at another v1 API (for example `/api/v1/rider`) by switching the last segment. A Linux debug build defaults to `http://127.0.0.1:8000/api/v1/transport-drivers`.

## Launcher icon and launch splash

Both come from [`assets/images/driver_logo.png`](../../vendo_driver/assets/images/driver_logo.png), the truck-and-lightning badge drawn on its cream `#FEF8E8` background.

- **Launcher icon** — the icon uses [`assets/images/driver_logo_icon.png`](../../vendo_driver/assets/images/driver_logo_icon.png), the same artwork scaled to 78% on a softened copy of its own background, because full-bleed artwork read as too zoomed in on a home screen. `flutter_launcher_icons` is configured in `pubspec.yaml`; re-run `dart run flutter_launcher_icons` after replacing the image. It writes the Android `mipmap-*` icons, the Android adaptive icon (cream background, the padded logo as the full-bleed foreground) and the iOS `AppIcon` set with alpha removed. The padding lives in the image, so `mipmap-anydpi-v26/ic_launcher.xml` draws the foreground without the tool's default 16% inset; a re-run restores that inset, so remove it again if you regenerate.
- **Launch splash** — `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` show `drawable-*/launch_image.png` centred on `@color/launch_background` (`#FEF8E8`), and `values-v31/styles.xml` gives Android 12+ the same cream background and logo through `windowSplashScreenBackground` / `windowSplashScreenAnimatedIcon`. iOS uses the cream background in `LaunchScreen.storyboard` with `LaunchImage.png`, `@2x` and `@3x` in `LaunchImage.imageset`.

The splash images are plain resizes of the logo (144 dp on Android, 144 pt on iOS), so replacing the artwork means regenerating those PNGs as well as the launcher icons.

## Design notes

Same palette as the Rider app: Prune `#412143`, Brique `#BF5E40`, Lin `#DBC583`, Raisin `#815488`, warm background `#FAF7F5`, ink `#2A1B2C`. Every tab starts with the dark gradient header, and all touch targets are at least 44–48 px. The bottom navigation is its own file so it can be replaced or hidden independently, and it uses the Rider app's floating glass bar with the sliding jelly pill indicator.

## Known gaps

- The manifest screen lists the trip manifest without a live per-parcel scan feed.
- Earnings are accrued ledger entries only. Payout execution, payslips and salary records are not implemented; the app says so.
- The trip API carries no route distance, so the distance rows show *Not shared by the hub* / `—` until the web sends one.
- The board shows only scheduled and in-transit trips; completed runs are on the separate Trip history screen (`GET /trips/history`, capped at 50, no date filter).
- Password recovery depends on the web sending the reset email; a failure there is only visible in the server log, and the app shows the same neutral message either way.
- No push notification when the hub approves or rejects; the applicant sees it on the next sign-in or status check.
- Load scanning covers the origin only. The destination hub still scans each parcel with its own station scanner before the trip can close.
- The scan screen holds the camera open while it is on screen; there is no background or headless scanning.
- There is no container record in the database: a container label is just a QR that lists tracking numbers, so nothing groups those parcels after they are loaded and no container can be searched by its own code.
- Incident/discrepancy forms and salary are still missing.
- There are no push notifications: the driver sees new rows when the shell loads, on pull-to-refresh, or when the bell is opened, and nothing polls in the background.
- No map or turn-by-turn navigation. The trip status screen shows the planned route and ETA, not live GPS.
- No automated tests are kept in the repository; the owner performs device testing.
