# CLAUDE.md — Elkasir POS (mobile)

**Elkasir POS** (`elkasir_pos`) is the **Flutter cashier app** of the Elkasir multi-tenant
**F&B POS** platform. It is the till that **POS staff** operate at the counter — roles
**cashier** and **supervisor**. This file is the gateway; read it before changing code.

## This app is NOT standalone — it is bound to the Elkasir backend

- It is a **thin client over the shared Go API** that lives in the **sibling project
  `../elkasir_web`** (`apps/api`, served under **`/api/v1`**). The server owns the data, the
  money math, auth, roles, and multi-tenancy. This app has **no local database** and is not a
  source of record.
- API base URL: [lib/core/config/app_config.dart](lib/core/config/app_config.dart) — defaults to
  **production** `https://elkasir.elcodelabs.com/api/v1`. Override without editing code:
  `flutter run --dart-define=API_BASE_URL=http://<lan-ip>:8081/api/v1`.
- The backend knowledge base is **authoritative** for domain/contract questions — read it before
  guessing an endpoint, envelope, role, or pricing rule:
  **`../elkasir_web/CLAUDE.md`** and **`../elkasir_web/knowledge/`**
  (`API_GUIDE.md`, `DOMAIN_GLOSSARY.md`, `MODULE_MAP.md`, `DATABASE_GUIDE.md`). OpenAPI contract:
  `../elkasir_web/packages/api-contract`.
- There is **no offline mode**: login, catalog, config, and every sale hit the API. The tablet
  needs network. (Hardware/runbook context for the deployed tablet is in this repo's history.)

## Roles (the POS actor type is `staff`)

| Role | Can do |
|---|---|
| **cashier** | Open/close own shift, take counter orders, accept cash/QRIS, print receipts, open the drawer, redeem pay-at-cashier self-orders. Sees only its own shift's transactions. |
| **supervisor** | Everything a cashier does **plus** cash movements & printer settings, and is the **approver** for: discount above the store cap, transaction **void**, and shift close beyond variance tolerance. |

The app **hides** supervisor-only surfaces from cashiers, but **enforcement is server-side**: a
cashier supplies a **supervisor PIN** that the API verifies (bcrypt) for over-cap discount, void,
and over-tolerance close. Never treat client-side gating as the security boundary.

## The server is the source of truth

- Money is computed and recorded by the server. [lib/core/pricing.dart](lib/core/pricing.dart)
  **mirrors** the server's `pricing.go` for live display only; the receipt is rebuilt from
  server-returned values after a sale. Do **not** move money/total/tax/change logic into the client.
- Feature flags + thresholds (service %, PPN, QRIS on/off, self-order on/off, discount cap, expense
  cap, variance tolerance) come from `GET …/pos/config` and are cached as last-known-good.
- Sales are **idempotent**: each sale sends an `Idempotency-Key`; the app keeps **one key per
  pending sale** so a retry after a network timeout replays on the server instead of duplicating.

## Stack & architecture

- **Flutter 3.x / Dart ≥ 3.8**, **Riverpod** — a single `AppController extends Notifier<PosAppState>`
  ([lib/features/app_controller.dart](lib/features/app_controller.dart)) holds POS state and
  orchestrates the API. `http` + `shared_preferences`.
- **Printing / hardware**: `printing`+`pdf` (system/PDF mode) and
  `print_bluetooth_thermal`+`esc_pos_utils_plus` (direct **ESC/POS over classic Bluetooth** + a
  cash-drawer kick). The cash drawer is opened by an ESC/POS command sent **through the thermal
  printer** (RJ11), not wired to the tablet. Receipt + drawer require the **Thermal Bluetooth**
  mode (printer paired first); the system/PDF mode cannot open the drawer.
- Layout:
  - `lib/core/` — config, constants, `pricing.dart` (server mirror), theme, formatters.
  - `lib/models/pos_models.dart` — domain types + enums that map to server strings.
  - `lib/services/api/` — one class per backend area (auth, products, transactions, shifts,
    cash_movements, self_orders, tables, config) over a shared `ApiClient`; JWT in `token_store.dart`.
  - `lib/services/` — printing services (`thermal_printer_service`, `printer_service`,
    `receipt_service`) + settings store.
  - `lib/features/` — screens (pos, checkout, receipt, shift, cash_movements, incoming,
    transactions, settings, auth) + `app_controller.dart`.
  - `lib/shared/` — generic widgets (incl. `supervisor_approval_dialog`).

## Auth & session

Staff login `POST /api/v1/auth/staff/login` → JWT access+refresh, persisted via
`shared_preferences`. Cold start restores the session (`…/me`) so the cashier isn't forced to
re-login; an invalid/expired token falls back to the login screen.

## Endpoints consumed (all under `/api/v1`)

`auth/staff/login` · `auth/.../refresh` · `auth/.../me` · logout — `GET /products` · `GET /tables`
· `GET …/pos/config` — shifts open/close/current — `POST /transactions` (idempotent) · list · void
— cash-movements list/create (supervisor) — self-orders list/update-status/redeem/redeem-checkout
— `POST …/pos/approvals/verify-pin`.

## Commands

```bash
flutter pub get
flutter run                                                       # talks to PRODUCTION API by default
flutter run --dart-define=API_BASE_URL=http://<lan-ip>:8081/api/v1  # point at a local backend
flutter build apk --release                                       # sideload to the cashier tablet
flutter analyze lib
```

## Rules when editing

- **Server is authoritative.** Keep `pricing.dart` a faithful mirror of `pricing.go`; never make
  the client the source of truth for money.
- **Don't rely on client-side role gating for security** — keep the server PIN/role checks intact
  and send exactly what the API expects.
- **Keep request/response shapes aligned with the backend contract** (`../elkasir_web` —
  `knowledge/API_GUIDE.md` + `packages/api-contract`). If a shape must change, change the backend
  contract too; the two repos move together.
