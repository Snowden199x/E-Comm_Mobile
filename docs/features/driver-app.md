# Vendo Driver app (UI)

**Status:** UI-only build of the Transport Driver app. No API, database, scanner or push notification is connected.
**Updated:** 30 October 2026

`vendo_driver/` is the Flutter app for the Transport Driver — the person in charge of the trucks and vans that move parcels between Stations and Province Hubs. It uses the same Vendo palette and Material 3 language as the Rider app, but it has its own screens and a separate bottom navigation widget. All trips, parcels and scans are demo data held in memory so the screens can be reviewed before the backend is wired.

## Scope

- The driver never collects or carries COD cash. A COD parcel is just a parcel. The manifest shows tracking numbers and statuses only: no addresses, buyer details, prices or COD amounts.
- Opening a manifest does not prove that every parcel arrived. Station scans are the proof of receipt. Dispatch requires every origin scan; closing the trip requires every destination scan.
- Container scanning, per-parcel scan status, incident/discrepancy reports, trip history, notifications and salary are later. They are labelled **Later** in the UI and are not functional.

## Screens

| Screen | File | What it does |
| --- | --- | --- |
| Sign in | [`driver_login_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_login_screen.dart) | Branded sign-in, password visibility, demo-account shortcut, registration link. |
| Register | [`driver_register_screen.dart`](../../vendo_driver/lib/features/auth/screens/driver_register_screen.dart) | Identity, Province Hub, company, vehicle type and plate, license number and expiry, password. Submits to a confirmation dialog only. |
| Shell | [`driver_shell.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_shell.dart) | Five-tab `IndexedStack` shell. |
| Bottom navigation | [`driver_bottom_nav.dart`](../../vendo_driver/lib/features/dashboard/widgets/driver_bottom_nav.dart) | Separate navigation widget: Home, Trips, Manifest, Earnings, Profile. |
| Home | [`driver_home_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_home_screen.dart) | Greeting, hub/company, active trips and parcels onboard, current trip card with the next action, upcoming trips. |
| Trips | [`driver_trips_screen.dart`](../../vendo_driver/lib/features/dashboard/screens/driver_trips_screen.dart) | All/Scheduled/In transit/Completed filters and trip cards. |
| Manifest | [`driver_manifest_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_manifest_screen.dart) | Parcel list with tracking numbers and statuses, search, origin/received counts, trip selector when embedded. |
| Trip details | [`driver_trip_details_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_details_screen.dart) | Route rail, schedule, vehicle, distance, scan progress, manifest shortcut. |
| Dispatch confirmation | [`driver_dispatch_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_dispatch_screen.dart) | Readiness checklist (vehicle, license, origin scans) and a Depart action that shows the server-style reason when blocked. |
| Trip status | [`driver_trip_status_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_trip_status_screen.dart) | In-transit timeline, ETA, parcels onboard, receiving count, handover action. |
| Destination handover | [`driver_handover_screen.dart`](../../vendo_driver/lib/features/trips/screens/driver_handover_screen.dart) | Receiving progress, pending tracking numbers, blocked reason, close-trip confirmation and a completed state that releases the vehicle. |
| Legacy earnings | [`driver_earnings_screen.dart`](../../vendo_driver/lib/features/earnings/screens/driver_earnings_screen.dart) | Old per-stop credits only, with a plain statement that this is not salary or payout. |
| Profile | [`driver_profile_screen.dart`](../../vendo_driver/lib/features/profile/screens/driver_profile_screen.dart) | License and expiry, contact details, hub/company/vehicle, later features, sign out. |

Shared pieces live in [`vendo_theme.dart`](../../vendo_driver/lib/core/theme/vendo_theme.dart) (palette and Material theme), [`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) (demo trips, profile, depart/arrive rules) and [`driver_ui.dart`](../../vendo_driver/lib/features/shared/widgets/driver_ui.dart) (headers, cards, pills, route rail, bottom action bar).

## Navigation

The five tabs are Home, Trips, Manifest, Earnings and Profile. Manifest doubles as a tab and as a pushed screen: opened from a trip it shows that trip's manifest with a back button; opened from the tab it shows the current trip and lets the driver switch between non-completed trips.

Trip details, dispatch confirmation, trip status and destination handover are pushed on top of the shell in that order. Closing a trip returns to the root shell, where the completed trip is gone from the current card and the next scheduled trip becomes current.

## Demo behaviour

[`driver_store.dart`](../../vendo_driver/lib/core/data/driver_store.dart) seeds three trips:

- **TRP-2406** — 12 of 12 parcels scanned at the Laguna Province Hub. Departing moves it to In Transit.
- **TRP-2407** — only 6 of 8 parcels scanned at Santa Cruz Station, so dispatch is deliberately blocked and its reason is shown.
- **TRP-2408** — 20 parcels, scheduled for tomorrow.

`depart()` and `arrive()` return an empty string on success and a human-readable reason on failure. The UI presents that reason in a bottom sheet, the way a server rejection should appear. Because there is no station scanner in this build, the handover screen has a clearly labelled **Demo: simulate station scans** action; it is scaffolding, not a claim that scans happened.

Demo changes are in memory only and reset when the app restarts. Signing out does not clear them.

## Design notes

Same palette as the Rider app: Prune `#412143`, Brique `#BF5E40`, Lin `#DBC583`, Raisin `#815488`, warm background `#FAF7F5`, ink `#2A1B2C`. Every tab starts with the dark gradient header, and all touch targets are at least 44–48 px. The bottom navigation is its own file so it can be replaced or hidden independently.

## Known gaps

- No API, token storage, session or approval check. Any non-empty email and password opens the demo.
- No scanning, container labels, incident/discrepancy forms, trip history, notifications or salary.
- No map or turn-by-turn navigation. The trip status screen shows the planned route and ETA, not live GPS.
- No automated tests are kept in the repository; the owner performs device testing.
