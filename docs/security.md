# Rider Mobile Security

**Reviewed:** 28 September 2026  
**Scope:** `vendo_rider/` and its connection to the Vendo Laravel Rider API. This is a code-based snapshot, not a mobile penetration test or release certification.

## Trust boundary

The Flutter app is an untrusted client. It displays server-authorized Rider work and submits scan requests; it does not connect to MariaDB, decide assignments, approve accounts, or own parcel status. The Laravel API is authoritative for Rider identity, Main Hub membership, assignments, scan stage, and order state. See the [web/API security overview](../../E-Comm_Web/docs/security.md).

## Controls present in the app and API contract

- The Rider app sends a bearer token to the versioned `/api/v1/rider` API. It stores the token in `flutter_secure_storage`, not ordinary preferences. Logout requests server-side token revocation and clears local secure storage; an expired/revoked session is cleared when the server returns 401/403.
- The server only issues a Rider token to an approved, active Rider attached to an approved, active Main Hub. It rechecks approval and hub membership on protected requests. Tokens expire after seven days and are limited to the `rider:scan` ability.
- Assignment and scan authorization comes from the authenticated Rider and current server records. The app does not send an authoritative Rider or hub ID. QR/Code 128 tracking data identifies the parcel; it is not a credential or proof of permission.
- The app stores a pending scan UUID in secure storage so a connection retry can repeat the same event. The server enforces order assignment, current scan stage, and idempotency; the UUID does not authorize a scan.
- Email OTP and Google registration proofs are short-lived server-issued values. Google verification and account approval happen on the web API; the app does not treat a Google client response alone as Rider approval.
- Rider registration sends ID, driver-license, and OR/CR images to the API. Production app traffic must use HTTPS. The Rider API stores these documents on the server's private local disk.
- The Android release manifest does not enable cleartext HTTP. The Android debug manifest allows cleartext for local development. Keep that permission limited to debug builds and use HTTPS for production.

## App data and permissions

The app requests camera access for barcode/QR scanning and declares location and image-library permissions for existing map/profile capabilities. The live parcel scan does not attach GPS coordinates or claim proof of delivery. Assignment responses contain stop contact/address data for the assigned local Rider; Truck linehaul responses are intentionally narrower and omit buyer contact/address data.

The Google Maps key in `android/app/src/main/AndroidManifest.xml` is currently the placeholder `YOUR_API_KEY`. If Maps is enabled, configure a key restricted to the Android package and signing certificate, and to only the required Maps APIs. Do not put OAuth client secrets or server credentials in the Flutter app.

## Build and environment rules

- Production API traffic targets `https://vendo-ph.app/api/v1/rider`; use `VENDO_API_BASE_URL` only to point a development build at a deliberately reachable local/staging API.
- `GOOGLE_WEB_CLIENT_ID` is passed at build/run time as the Google server client ID and must also be allowed by the web API's `GOOGLE_ALLOWED_CLIENT_IDS`. Register the Android OAuth client with the app's exact package name and signing SHA-1 fingerprints. These IDs are not secrets; never bundle a client secret.
- Do not commit signing keys, Google Maps keys, production API credentials, device tokens, or real identity documents. Keep credentials out of logs and screenshots shared outside the team.
- Debug HTTP settings are for local development only. A production build must use HTTPS and release signing credentials controlled by the project owner.

## Known gaps and limits

- Seven-day tokens have no Rider-facing device/session manager. Password reset revokes existing tokens; a lost device should be handled by resetting the Rider password or having an administrator disable the account while server-side token/device revocation is improved.
- Secure storage protects app secrets at rest through platform facilities, but does not protect a compromised/rooted device, an unlocked phone, screenshots, or data exposed by the operating system.
- There is no independent photo/signature/OTP delivery proof, GPS attestation, offline scan queue, or SubHub scanner authorization in this Rider app. A `delivered` scan records the assigned Rider's report; buyer receipt confirmation remains separate.
- Review build signing, Android package/SHA configuration, Google OAuth allowlists, release HTTPS/API routing, and backup/storage handling before distributing a release. Owner/device verification and an independent security review remain pending.

## Source references

`vendo_rider/lib/core/api/rider_api.dart`, `vendo_rider/lib/features/auth/screens/login_screen.dart`, `vendo_rider/lib/features/auth/screens/register_screen.dart`, `vendo_rider/lib/features/work/screens/rider_work_screen.dart`, Android manifests, and the [web Rider scan API contract](../../E-Comm_Web/docs/features/courier/scan-api/spec.md).
