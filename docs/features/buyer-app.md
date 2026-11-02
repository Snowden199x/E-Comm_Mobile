# Buyer app

The Vendo Buyer mobile app reads `GET /api/v1/buyer/*` with a stored bearer token and signs in with email/password or Google. Orders, one order's tracking detail, and notifications each cache their last successful payload on the device through `OfflineStore` (`lib/core/offline/offline_store.dart`), which lives in the same encrypted storage as the login token.

When the API cannot be reached, Orders, Order tracking, and Notifications fall back to that saved payload and show an "Offline — showing saved details" banner naming when the data was saved, with a Retry action. A Buyer never sees an empty error page for data the phone already has.

Small, safe account writes are queued in an outbox and uploaded automatically: marking all notifications read is kept on the device and flushed later. Placing an order is deliberately never queued — stock, vouchers, the COD amount, and the delivery route must be confirmed by Vendo before an order exists.

`OfflineSyncService` watches `connectivity_plus` events, retries queued work every 45 seconds while anything is pending, and retries on app start, so a queued action uploads without the Buyer reopening a screen. Entries the server can no longer accept (4xx) are dropped so one stale action cannot block the rest, and logging out clears both the cache and the outbox.
