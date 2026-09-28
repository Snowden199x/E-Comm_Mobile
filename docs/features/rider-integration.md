# Rider registration and parcel scans

**Status:** Implemented client for the currently available Laravel rider API; owner verification pending  
**Updated:** 28 September 2026

## Registration

The rider selects a province and municipality/city from the web app's PSGC snapshot, then a searchable barangay list loaded from `GET /api/v1/rider/locations/{cityCode}/barangays`. The app submits all three location codes, personal details, a Motorcycle, Van, L300, or Truck vehicle, a valid ID, driver license, and OR/CR image as multipart form data. The API verifies that the barangay belongs to the chosen city and the city belongs to the province, then chooses a unique approved active hub: exact city when unique, otherwise unique province. No arbitrary center or GPS-distance fallback exists. Unmatched or ambiguous addresses return a validation error and do not create an application. The created Rider account is pending and appears in that center's Rider Management queue. The center approves or rejects it in the web app.

Before the app submits a Rider application, it must verify the email using the API's six-digit email OTP or a short-lived Google registration proof returned after server-side Google ID-token verification. Both proofs are bound to the normalized email, expire, and are consumed after successful registration. Google newcomers continue into the same application form with name/email prefilled; Google only replaces email OTP and does not skip password, profile, address, private documents, hub matching, or Logistics approval.

The app cannot guarantee that a chosen hub is physically closest. Hub coverage and reassignment rules need separate operational decisions. Identity images are uploaded to private server storage; the hub reviewer currently has no dedicated authorized document download screen.

## Authentication and assigned work

Only approved active riders attached to approved active centers can log in with a password or Google. The API verifies Google ID tokens and issues the same seven-day Rider bearer token; pending accounts still need Logistics approval. Forgot Password emails a one-time code, exchanges a valid code for a short-lived reset proof, changes the password, and revokes existing Rider API tokens. The token, rider name, center name, and registered vehicle type are stored in platform secure storage. The live work screen requests assigned parcels from the server and displays the seller stop for pickup or buyer stop for delivery. Motorcycle, Van, and L300 accounts use local pickup/delivery assignments; only Truck accounts receive long-haul work. The previous sample dashboard is not used for live work.

For a selected assignment, the camera reads the label's QR or Code 128 barcode; both encode the same tracking number, and only an exact match with the assigned parcel is accepted. Android/iOS explicitly configure `mobile_scanner` for those two formats. Linux explicitly enables both in `zbarcam`. A matching read sends the supported `pickup`, `origin_arrival`, `out_for_delivery`, or `delivered` action according to the assignment's current server status. Legacy SOC-coded scan actions are not presented as actual SH arrivals. The `delivered` scan appears after `out_for_delivery` and should be used only after handing over the parcel; the Laravel API restricts it to the approved rider assigned for destination delivery. A UUID scan key is stored before the network call and reused if a connection fails; successful scans clear it. The Laravel API authorizes the rider and order, records the scan, and updates notifications and the seller/buyer timeline. A scan is not treated as successful merely because the camera read a code.

The web API returns the registered vehicle type and assigned Truck linehaul work with origin/destination Main Hubs, ordered planned checkpoints, and the next planned checkpoint. The additive web migration `2026_09_28_200000_add_linehaul_rider_to_orders.php` must be applied before Truck assignments can be queried. Truck tasks are read-only: the Rider app does not record truck departure/arrival or custody. The separate SH scanner app will own actual SH arrival/sorting scans and route progression. The mobile client does not treat route plans or a QR/barcode as proof of arrival or custody.

`delivered` is the last currently supported delivery scan. It is the rider's report of handover, not a signature, photo, GPS proof, or buyer receipt confirmation. The buyer confirms receipt separately in the web order page, then can rate purchased products. SOC5 and SOC6 are transitional API statuses and are not shown by the Rider app as proof of location in a physical SH. Actual destination-hub receipt is confirmed by that hub's web account.

## Integration configuration

- Default production API: `https://vendo-ph.app/api/v1/rider` over HTTPS. A Linux debug build defaults to `http://127.0.0.1:8000/api/v1/rider`, so the local Laravel server must be running on port 8000. Location-load errors display the API URL to make a missing or outdated backend clear.
- For an Android emulator and a locally served backend, build with `--dart-define=VENDO_API_BASE_URL=http://10.0.2.2:8000/api/v1/rider` if port 8000 is the web server's port. An Android emulator cannot use its own `127.0.0.1` to reach the host. The debug manifest permits local HTTP; release remains HTTPS only. A physical device needs a server address reachable from its network. To point a Linux debug build at the deployed API, pass `--dart-define=VENDO_API_BASE_URL=https://vendo-ph.app/api/v1/rider`.
- Dependencies for HTTP, secure token storage, camera scanning, and `google_sign_in` are declared in `vendo_rider/pubspec.yaml` and resolved in `pubspec.lock`. The Rider Google plugin supports Android/iOS/macOS, not Linux desktop. Configure the Google Cloud OAuth clients: Android package name plus signing SHA fingerprints, iOS bundle/client ID plus reversed client URL scheme, and macOS bundle/client ID plus its callback URL scheme. Pass the server/web client with `--dart-define=GOOGLE_WEB_CLIENT_ID=...`; iOS/macOS can pass `--dart-define=GOOGLE_IOS_CLIENT_ID=...` or `--dart-define=GOOGLE_MACOS_CLIENT_ID=...`. These IDs must be allowed by the web API's `GOOGLE_ALLOWED_CLIENT_IDS`. Google sign-in cannot run on the Linux desktop client; email OTP and password-reset API flows still work there. No app tests, builds, or device walkthroughs were run by the agent per the owner's instruction.
- Android/iOS use `mobile_scanner` with QR and Code 128 explicitly enabled. On Linux, the scan screen starts the system `zbarcam --raw` webcam reader with those two formats enabled and waits for an exact tracking-number match. `zbarcam` opens its own preview window; no camera image or decoded mismatched code is uploaded. Install Fedora's `zbar` package before using this path. The owner still needs to verify both printed formats with a real device or webcam.

### Fedora Linux desktop prerequisite

The Linux implementation of `flutter_secure_storage` compiles against `libsecret-1`. On Fedora, install its development package before building the desktop app:

```bash
sudo dnf install libsecret-devel zbar
```

Then retry `flutter run -d linux` from `vendo_rider/`. This package is a machine-level build prerequisite; it is not a Laravel migration or a Flutter source change. The Fedora runtime package `libsecret` is already present on the current development machine, but `libsecret-devel` was missing on 27 September 2026. The agent could not install it because sudo required the owner's password and did not run the app.
