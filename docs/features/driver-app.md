# Vendo Driver app

**Status:** Registration, application status, sign-in, session restore, password reset and the trip board (`GET /trips`, depart, arrive) are connected to the web API. Earnings still use demo data.
**Updated:** 2 November 2026

`vendo_driver/` is the Flutter app for the Transport Driver — the person in charge of the trucks and vans that move parcels between Stations and Province Hubs. It uses the same Vendo palette and Material 3 language as the Rider app, but it has its own screens and a separate bottom navigation widget.

## Scope

- The driver never collects or carries COD cash. A COD parcel is just a parcel. The manifest shows tracking numbers and statuses only: no addresses, buyer details, prices or COD amounts.
- Opening a manifest does not prove that every parcel arrived. Station scans are the proof of receipt. Dispatch requires every origin scan; closing the trip requires every destination scan.
- Container scanning, per-parcel scan status, incident/discrepancy reports, trip history, notifications and salary are later. They are labelled **Later** in the UI and are not functional.

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

Documents: the licence and a valid ID are photographed or picked from the gallery and uploaded privately as `drivers_license` and `valid_id`.

Email verification uses the same sheet as the Rider and Buyer registrations: the Email label has a **Verify** link that opens a bottom sheet with six digit boxes and sends the code straight away (`POST /email/otp/send`). The boxes move on their own, the code is checked as soon as all six digits are in (`POST /email/otp/verify`), and **Resend Code** is available. On success the email field shows a green *Verified* mark and the returned `verification_token` is sent with the application. Changing the email clears it, and Step 1 does not advance until the email is verified.

After submitting, the success sheet names the hub that reviews the application and the Station Hub the driver is linked to, then returns to sign-in.

## Sign in and application status

Sign-in calls `POST /api/v1/transport-drivers/login` with the email and password and keeps the token in secure storage. Two states are explained instead of a generic failure:

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
| API client | [`driver_api.dart`](../../vendo_driver/lib/core/api/driver_api.dart) | Hubs, PSGC locations, email code, register (multipart), login, session profile (`me`), password reset, application status, token and profile storage. |
| Shell | [`driver_shell.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_shell.dart) | Five-tab `IndexedStack` shell. |
| Bottom navigation | [`driver_bottom_nav.dart`](../../vendo_driver/lib/features/dashboard/widgets/driver_bottom_nav.dart) | Separate navigation widget: Home, Trips, Manifest, Earnings, Profile. Same floating frosted-glass bar and sliding jelly pill as the Rider app; icons only, with the active icon turning white under the pill. |
| Home | [`driver_home_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_home_screen.dart) | Greeting with today's date and the vehicle/plate, tappable avatar that opens Profile, licence-expiry warning from 30 days out, sync strip, active trips and parcels onboard, quick actions (Manifest, Dispatch, Trip status), current trip card with scan progress, upcoming trips. Pull down to refresh from the API. |
| Trips | [`driver_trips_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_trips_screen.dart) | All/Scheduled/In transit/Completed filters and trip cards. |
| Manifest | [`driver_manifest_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_manifest_screen.dart) | Parcel list with tracking numbers and statuses, search, origin/received counts, trip selector when embedded. |
| Trip details | [`driver_trip_details_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_details_screen.dart) | Route rail, schedule, vehicle, distance, scan progress, manifest shortcut. |
| Dispatch confirmation | [`driver_dispatch_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_dispatch_screen.dart) | Readiness checklist (vehicle, license, origin scans) and a Depart action that shows the server-style reason when blocked. |
| Trip status | [`driver_trip_status_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_status_screen.dart) | In-transit timeline, ETA, parcels onboard, receiving count, handover action. |
| Destination handover | [`driver_handover_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_handover_screen.dart) | Receiving progress, pending tracking numbers, blocked reason, close-trip confirmation and a completed state that releases the vehicle. |
| Legacy earnings | [`driver_earnings_screen.dart`](../../vendo_driver/lib/features/earnings/screens/driver_earnings_screen.dart) | Old per-stop credits only, with a plain statement that this is not salary or payout. |
| Profile | [`driver_profile_screen.dart`](../../vendo_driver/lib/features/profile/screens/driver_profile_screen.dart) | License and expiry, contact details, hub/company/vehicle, later features, sign out. |

Shared pieces live in [`vendo_theme.dart`](../../vendo_driver/lib/core/theme/vendo_theme.dart) (palette and Material theme), [`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) (trip board, profile, depart/arrive) and [`driver_ui.dart`](../../vendo_driver/lib/features/shared/widgets/driver_ui.dart) (headers, cards, pills, route rail, bottom action bar).

## Navigation

The five tabs are Home, Trips, Manifest, Earnings and Profile. Manifest doubles as a tab and as a pushed screen: opened from a trip it shows that trip's manifest with a back button; opened from the tab it shows the current trip and lets the driver switch between non-completed trips.

Trip details, dispatch confirmation, trip status and destination handover are pushed on top of the shell in that order. Closing a trip returns to the root shell, where the completed trip is gone from the current card and the next scheduled trip becomes current.

## Trips from the web

[`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) loads the board with `GET /api/v1/transport-drivers/trips`, which returns the driver's scheduled and in-transit trips, in-transit first:

| Field | Use in the app |
| --- | --- |
| `id`, `code` | The code is shown (`TRP-00042`); the id is what the depart and arrive calls address. |
| `status` | `scheduled` / `in_transit` / `completed`, mapped to the app's `TripStatus`. |
| `origin`, `destination` | Hub names with the municipality and province joined as the area line. |
| `scheduled_departure_at`, `expected_arrival_at`, `departed_at`, `arrived_at` | The schedule, ETA and timeline. A trip with no schedule falls back to when it actually left, then to now. |
| `vehicle` | Type and plate, falling back to the profile when the trip has no vehicle row. |
| `manifest` | Tracking numbers only: no addresses, buyer details, prices or COD amounts. |
| `origin_scanned`, `destination_scanned` | How many manifest parcels carry the origin departure scan and the destination arrival scan. These are the same scans the workflow checks before it lets a trip depart or close, so the progress bars show real counts. |

The board refreshes on three occasions: when the shell opens, when the driver pulls the Home list down, and when **Refresh** is tapped. The strip under the greeting says where the data came from — *Updated 2 min ago from Vendo*, *Loading the trips your hub assigned…*, or *These are sample trips* — and a failure shows a red notice with **Retry**. When the server answers `401` the stored session is cleared and the notice offers **Sign in**, which drops the token and opens the sign-in screen.

**Departing and arriving** call `POST /trips/{id}/depart` and `POST /trips/{id}/arrive` on live trips and keep the answer the server returns in place of the local trip, so the status, scans and ETA follow the web. A refusal (an unscanned parcel, an open exception, a dropped connection) is shown in the blocked sheet with the server's own reason. Local rules stay for the sample trips, which are only used before the first successful load and are kept on screen when the network is down.

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

## Design notes

Same palette as the Rider app: Prune `#412143`, Brique `#BF5E40`, Lin `#DBC583`, Raisin `#815488`, warm background `#FAF7F5`, ink `#2A1B2C`. Every tab starts with the dark gradient header, and all touch targets are at least 44–48 px. The bottom navigation is its own file so it can be replaced or hidden independently, and it uses the Rider app's floating glass bar with the sliding jelly pill indicator.

## Known gaps

- The trip board, dispatch and handover are API-backed. Earnings still reads the legacy demo credits, and the manifest screen lists the trip manifest without a live per-parcel scan feed.
- The trip API carries no route distance, so the distance rows show *Not shared by the hub* / `—` until the web sends one.
- The board shows the trips the API returns (scheduled and in transit); completed trips drop off on the next refresh, and the app keeps no trip history.
- Password recovery depends on the web sending the reset email; a failure there is only visible in the server log, and the app shows the same neutral message either way.
- No push notification when the hub approves or rejects; the applicant sees it on the next sign-in or status check.
- No scanning, container labels, incident/discrepancy forms, trip history, notifications or salary.
- No map or turn-by-turn navigation. The trip status screen shows the planned route and ETA, not live GPS.
- No automated tests are kept in the repository; the owner performs device testing.
