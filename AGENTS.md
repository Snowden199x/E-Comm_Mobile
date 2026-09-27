# Working Rules for Vendo Mobile

## Scope

- These rules apply to this Flutter repository, including `vendo_rider/` and `vendo_buyer/`. Follow the user's current request first. Inspect `git status` before editing and preserve unrelated work. Stay on the current branch; do not commit unless asked.
- This repository is separate from the Laravel web repository at `../E-Comm_Web`. Use the web app's live routes, models, and `docs/` as the source of truth for server behavior. Do not copy web controllers, migrations, or Laravel instructions into Flutter.
- Read `docs/README.md`, `docs/architecture.md`, `docs/domain-feature-status.md`, and the relevant mobile feature spec before changing behavior. For cross-repository changes, read the corresponding web feature spec and API implementation.

## Working loop

1. Identify the mobile screen, client/service, platform permissions, API endpoint, authentication rule, and affected spec. Keep the change focused on the requested feature.
2. Make the smallest complete change. Keep tokens in secure storage, never log passwords, tokens, IDs, addresses, or document contents, and never trust a request-supplied hub ID. Show server errors honestly and distinguish actual scans from planned route checkpoints.
3. Document every code change in the same session. Update the affected `docs/features/*.md` and `docs/domain-feature-status.md` when behavior changes. Add a concise entry to `docs/logs/PROGRESS-YYYY-MM-DD.md` using the Asia/Manila date, including changed files, reason, and known gaps. Keep `docs/architecture.md` and `docs/README.md` current.
4. The owner performs testing. Do not create or run automated tests, browser tests, or manual app walkthroughs unless explicitly asked. Static code and diff review is allowed; report unverified behavior plainly.

## Boundaries and security

- The rider app calls the versioned Laravel `/api/v1/rider` endpoints; it does not write directly to MariaDB and does not independently assign riders or parcels. Courier approval belongs to the matched logistics center in the web app.
- Residence-based matching uses the web app's PSGC province/city catalog and a unique approved, active logistics hub in the same city or province. This is not a GPS nearest-hub calculation. Do not fall back to an arbitrary hub when matching is absent or ambiguous.
- Rider bearer tokens require an approved, active rider linked to an approved, active center. The server must authorize every assignment and scan. A scanned tracking code identifies a parcel; it is not authorization.
- Scans use one stable UUID key per event for retries. Current server-supported rider actions are seller pickup, arrival at origin hub, three virtual inter-hub scans by the assigned origin pickup rider, out for delivery, and a delivered scan by the assigned destination rider. Actual destination receipt is confirmed by its logistics web account. Buyer receipt confirmation remains a separate web action; earnings and independent proof of delivery are not live rider actions.
- Keep verification documents private and upload only to the authorized API. Use HTTPS for `vendo-ph.app`. A Linux debug build defaults to the local Laravel API on `127.0.0.1:8000`; other local or staging API URLs must be explicit through build configuration. Do not commit secrets, API keys, or production credentials.
- The buyer app is separate work. Do not present its mock screens as integrated or modify it while doing rider-only tasks unless requested.

## UI and dependencies

- Keep Vendo's existing visual language; use the `uncodixfy` skill for frontend UI when available. Make touch controls readable, accessible, and usable on small screens. State loading, empty, and error states truthfully.
- Check existing packages and platform setup before adding dependencies. Document necessary packages and platform permissions. Avoid unrelated file moves or broad cleanup.
- If a schema change is necessary in the web repository, add a new migration there and tell the owner before migration is run. The owner runs migrations.
