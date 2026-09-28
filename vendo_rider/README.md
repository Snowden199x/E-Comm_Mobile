# Vendo Rider

Flutter app for approved Motorcycle, Van, L300, and Truck riders. Rider registration, assignments, scans, account approval, parcel status, and notifications use the Vendo Laravel API; the app does not access the database directly.

## Run locally

From this directory, run `flutter pub get`, then `flutter run` for the connected target. Linux debug builds default to the web app at `http://127.0.0.1:8000/api/v1/rider`. Android emulators need the host alias, for example `--dart-define=VENDO_API_BASE_URL=http://10.0.2.2:8000/api/v1/rider`. Production defaults to `https://vendo-ph.app/api/v1/rider`.

The local Linux camera path uses `zbarcam`; Linux builds also need the platform `libsecret` development package. Android and iOS use the device camera through `mobile_scanner`.

## Current limits

Before using Truck linehaul assignments, apply the web migration `2026_09_28_200000_add_linehaul_rider_to_orders.php` from the E-Comm_Web repository with `php artisan migrate`. The owner runs the migration.

The app supports assigned seller pickup, origin Main Hub arrival, local delivery scans, and delivered reports. Truck linehaul assignments and planned routes are exposed read-only by the web API. Truck departure/arrival and SH arrival/sorting remain future API work; SH scans belong to the separate scanner app. See the mobile [Rider integration spec](../docs/features/rider-integration.md), [architecture](../docs/architecture.md), and [domain status](../docs/domain-feature-status.md). The owner performs device and workflow verification; no test or app walkthrough is implied by this README.
