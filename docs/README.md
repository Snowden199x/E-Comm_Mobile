# Vendo Mobile documentation

This folder records the current Flutter implementation and the contract with the separate Vendo Laravel web application. Start with [architecture](architecture.md), [domain status](domain-feature-status.md), and the [rider integration spec](features/rider-integration.md). The [29 October progress log](logs/PROGRESS-2026-10-29.md) records the consolidated Rider delivery screens and the new On the way states.

The web app's [rider scan API spec](../../E-Comm_Web/docs/features/courier/scan-api/spec.md) and [order/logistics decisions](../../E-Comm_Web/docs/order-logistics-flow-decisions.md) define server-owned behavior. The 14 October [Truck facility scan progress](logs/PROGRESS-2026-10-14.md) records the Rider app connection. If the web code and a document differ, inspect the live code and update the affected docs in both repositories. `AGENTS.md` at the mobile repository root defines the working rules.
The [Rider security overview](security.md) records mobile token/data handling, Android build boundaries, API trust assumptions, and open release risks.
