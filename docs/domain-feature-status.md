# Mobile feature status

**Reviewed:** 27 September 2026

| Area | Current state | Remaining work |
| --- | --- | --- |
| Rider registration | Form sends personal, vehicle, residence, and document data to the web API. PSGC province/city/barangay choices come from the web API; validated city and barangay codes drive server-side unique hub matching, and the application starts pending for that hub. | Hub reviewer document access, account recovery, and email verification are not integrated. No GPS nearest-hub selection. Bundled PSGC data needs periodic refresh. |
| Rider authentication | Approved rider login obtains a seven-day Sanctum token, stored securely; logout revokes it. | Token/device management and password reset are not integrated. |
| Assigned rider work | Live assigned-work screen shows only server-assigned pickup and delivery stops. QR and Code 128 barcode readers are explicitly enabled; an exact assigned tracking-number match sends pickup, origin arrival, three virtual inter-hub milestones, out-for-delivery or delivered with a retry key. Linux uses the system webcam reader; Android/iOS use the Flutter scanner. | Actual destination receipt remains a logistics web confirmation. Separate linehaul rider handoff, independent delivery proof, failed attempts, and broad offline queue are not implemented. Printed-label scanning awaits owner verification. |
| Prototype rider dashboard | Existing dashboard, earnings, delivery-detail and map pages remain in source but are not the live post-login flow. | Replace with verified API data if these features are later built. Do not use their sample rows as operational records. |
| Buyer app | Separate Flutter prototype; not changed by this rider integration. | Review against the web buyer API in its own task. |

Status describes code scope, not a claim of device or production testing. The owner performs acceptance testing.
