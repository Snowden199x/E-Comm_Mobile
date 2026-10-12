# Mobile feature status

**Reviewed:** 12 October 2026

| Area | Current state | Remaining work |
| --- | --- | --- |
| Rider registration | Refreshed four-step form still sends personal, Motorcycle/Van/L300/Truck vehicle, residence, and document data to the web API after six-digit email OTP or server-verified Google email proof. Google newcomers complete the regular application; matched hub review is still required. | Hub reviewer document access and no-GPS hub matching remain. Bundled PSGC data needs periodic refresh. Google sign-in requires OAuth setup and Android/iOS/macOS. |
| Rider authentication | Refreshed login calls the API; approved rider password or Google login obtains the seven-day Sanctum token and now opens the API-backed RiderWork screen. Logout revokes the token. Forgot Password verifies email OTP, resets the password, and revokes existing rider tokens. | Google OAuth setup and owner verification are pending; Google is unavailable on Linux desktop. |
| API-backed rider work | Successful password and Google login open `RiderWorkScreen`, which fetches server-assigned pickup/delivery work and supports the current QR/Code 128 scans with a retry key. Linux uses the system webcam reader; Android/iOS use the Flutter scanner. | Truck assignments/planned routes are read-only; truck movement and SH handoff remain unavailable in the API, while SH arrival/sorting belongs to the separate scanner app. Actual destination receipt remains a Logistics web confirmation. Independent delivery proof, failed attempts, and broad offline queue remain open. |
| Post-login dashboard prototype | The five-tab Home, Parcels, Map, Earnings and Profile interface remains in the code but is not the successful-login destination. Its sample parcels/earnings and fixed Bubukal map are not operational records. | Connect those tabs to authorized API data in a later dashboard slice if the five-tab shell is still desired. |
| Buyer registration prototype | New multi-step registration UI has personal details, an email-verification modal, ID capture, address fields, terms checkbox, review and success screen. | It does not call a Buyer API: OTP verification and success are visual only, and no Buyer account is created. Buyer app remains separate from this Rider integration. |

Status describes code scope, not a claim of device or production testing. The owner performs acceptance testing.
