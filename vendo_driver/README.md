# Vendo Driver

UI for the Vendo Transport Driver: the person who moves parcels between
Stations and Province Hubs. This build is **UI only** — there is no API call and
no database. All trips and scans are demo data held in memory, so the screens
can be reviewed and redesigned before the backend is connected.

The palette matches `vendo_rider` (Prune `#412143`, Brique `#BF5E40`, Lin
`#DBC583`, Raisin `#815488`, warm `#FAF7F5` background).

## Screens

| Screen | File |
| --- | --- |
| Sign in | `lib/features/auth/screens/driver_login_screen.dart` |
| Register | `lib/features/auth/screens/driver_register_screen.dart` |
| Dashboard shell (5 tabs) | `lib/features/dashboard/screens/driver_shell.dart` |
| Bottom navigation (separate) | `lib/features/dashboard/widgets/driver_bottom_nav.dart` |
| Home / current trip | `lib/features/dashboard/screens/driver_home_screen.dart` |
| Trips board | `lib/features/dashboard/screens/driver_trips_screen.dart` |
| Manifest | `lib/features/trips/screens/driver_manifest_screen.dart` |
| Trip details | `lib/features/trips/screens/driver_trip_details_screen.dart` |
| Dispatch confirmation | `lib/features/trips/screens/driver_dispatch_screen.dart` |
| Trip status (in transit) | `lib/features/trips/screens/driver_trip_status_screen.dart` |
| Destination handover | `lib/features/trips/screens/driver_handover_screen.dart` |
| Legacy earnings | `lib/features/earnings/screens/driver_earnings_screen.dart` |
| Profile | `lib/features/profile/screens/driver_profile_screen.dart` |

Shared pieces live in `lib/core/theme/vendo_theme.dart` (palette and Material
theme), `lib/core/data/driver_store.dart` (demo trips, profile, depart/arrive
rules) and `lib/features/shared/widgets/driver_ui.dart` (headers, cards, pills,
route rail, action bar).

## Demo walkthrough

1. Tap **Use demo account**, then **Sign in**.
2. **Home** shows current trip `TRP-2406` with 12 parcels, all scanned at the
   origin, and two upcoming trips.
3. **Confirm dispatch** → checklist → **Depart trip**. The trip moves to
   In Transit and the status screen opens.
4. **Destination handover**. The station has not scanned yet, so **Arrive and
   close trip** shows the server-style blocked reason. Use
   **Demo: simulate station scans**, then close the trip and the vehicle is
   released.
5. Trip `TRP-2407` is deliberately blocked: only 6 of 8 parcels are scanned at
   its origin, so its dispatch shows the blocked reason.

The manifest deliberately shows only tracking numbers and parcel statuses — no
buyer details, addresses or COD amounts.

## Run

```bash
cd E-Comm_Mobile/vendo_driver
flutter pub get
flutter run
```

`flutter test` covers the sign-in screen and the demo-account trip dashboard.
