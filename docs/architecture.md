# Mobile architecture

**Reviewed:** 27 September 2026

`vendo_rider/` is a Flutter application. Its registration screen uploads rider details and verification photos to `POST /api/v1/rider/register`; it loads province/city options from `GET /api/v1/rider/locations` and barangays from `GET /api/v1/rider/locations/{cityCode}/barangays`. The Laravel server verifies all three address codes and selects a unique approved, active logistics hub. The mobile app never sends a logistics-center ID.

After hub approval, the rider signs in through `POST /api/v1/rider/login`. The bearer token and rider/hub labels are stored with `flutter_secure_storage`. The live work screen reads only `GET /api/v1/rider/assignments`, reads the label's QR or Code 128 tracking number with explicitly configured `mobile_scanner` on Android/iOS or `zbarcam` on Linux, and sends `POST /api/v1/rider/scans` with a stable client UUID for retry. Logout calls the API token-revocation endpoint. Linux debug builds default to `http://127.0.0.1:8000/api/v1/rider`; other builds default to `https://vendo-ph.app/api/v1/rider`. Any build can override the API with `--dart-define=VENDO_API_BASE_URL=...`. Android requires Internet and camera permission; iOS requires camera/photo-library usage descriptions. Linux requires the system `zbar` command and `libsecret-devel` to build.

The existing dashboard, earnings, maps, and delivery-detail screens contain prototype data and are not the live work path. The old registration email-verification modal was also a prototype and has been removed from the registration flow. `vendo_buyer/` remains outside this rider change. The mobile app does not connect directly to the web database. The web app owns approval, assignment, parcel state, notifications, and the seller/buyer timeline.

The API's current scan actions are `pickup`, `origin_arrival`, `soc5`, `soc6`, `destination_hub`, `out_for_delivery`, and `delivered`. The three inter-hub actions are virtual route milestones scanned by the assigned origin pickup rider in order; the destination hub confirms real receipt in the web app. The assigned destination rider's `delivered` scan records a delivery report; the buyer confirms receipt separately before product rating. Independent delivery proof, push notifications, courier handoff, and offline scan queues need separate backend contracts. The app must not show those stages as completed without server confirmation.

The Android debug manifest permits cleartext HTTP for a local development endpoint. The release manifest does not enable cleartext, so production uses HTTPS.
