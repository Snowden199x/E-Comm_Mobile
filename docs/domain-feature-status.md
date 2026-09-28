# Mobile feature status

**Reviewed:** 28 September 2026

| Area | Current state | Remaining work |
| --- | --- | --- |
| Rider registration | Form sends personal, Motorcycle/Van/L300/Truck vehicle, residence, and document data to the web API after six-digit email OTP or server-verified Google email proof. Google newcomers complete the regular application; matched hub review is still required. | Hub reviewer document access and no-GPS hub matching remain. Bundled PSGC data needs periodic refresh. Google sign-in requires OAuth setup and Android/iOS/macOS. |
| Rider authentication | Approved rider password or Google login obtains the seven-day Sanctum token and returns/stores the registered vehicle type; logout revokes the token. Forgot Password verifies an email OTP, resets the password, and revokes existing rider tokens. | Device/token management remains. Google OAuth setup and owner verification are pending; Google is unavailable on Linux desktop. |
| Assigned rider work | Live assigned-work screen shows server-assigned pickup and delivery stops, labels the registered vehicle mode, and scans QR or Code 128 only for currently supported pickup/delivery actions with a retry key. Linux uses the system webcam reader; Android/iOS use the Flutter scanner. | Truck assignments and planned route display are available read-only; truck movement and SH handoff are not available in the API, while SH arrival and sorting belong to the separate scanner app. Actual destination receipt remains a Logistics web confirmation. Independent delivery proof, failed attempts, broad offline queue, and printed-label owner verification remain open. |
| Prototype rider dashboard | Existing dashboard, earnings, delivery-detail and map pages remain in source but are not the live post-login flow. | Replace with verified API data if these features are later built. Do not use their sample rows as operational records. |
| Buyer app | Separate Flutter prototype; not changed by this rider integration. | Review against the web buyer API in its own task. |

Status describes code scope, not a claim of device or production testing. The owner performs acceptance testing.
