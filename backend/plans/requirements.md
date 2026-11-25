# Backend Requirements (Entry Point)

## 1. Purpose & Scope
The centralized FastAPI backend powers all business rules, data persistence, concurrency protection, financial integrity, real-time tracking, notifications, and security across the Customer Website, Admin Desktop Dashboard, and Driver Mobile App.

## 2. Supplementary Requirement Documents
To keep every specification file <= 200 lines without losing detail, requirements are organized into:
- [req-booking-dispatch.md](req-booking-dispatch.md) — Services (`SVC-*`), Bookings (`BOOK-*`), Quotations (`QUOTE-*`), Dispatch (`DISP-*`)
- [req-fleet-driver-gps.md](req-fleet-driver-gps.md) — Fleet (`FLEET-*`), Maintenance (`MAINT-*`), Drivers (`DRV-*`), Trips (`TRIP-*`), GPS (`GPS-*`)
- [req-finance-ops.md](req-finance-ops.md) — Finance (`FIN-*`), CRM (`CRM-*`), Notifications (`NOTIF-*`), Reports (`RPT-*`), Reviews (`REV-*`), Security (`SEC-*`)

## 3. Roles & Permissions Overview
| Role Slug | Scope |
| --- | --- |
| `owner` | Full system access, staff/role management, system policies, audit logs |
| `booking_manager` | Enquiries, bookings, quotations, customer communications, cancellations |
| `fleet_manager` | Vehicle profiles, documents, availability calendar, maintenance schedules |
| `dispatcher` | Vehicle/driver eligibility, dispatch assignment/reassignment, live fleet monitoring |
| `accountant` | Invoices, payments, deposits, refunds, expenses, reconciliation, financial reports |
| `customer_support` | View bookings/customers, internal notes, incident follow-up (no refunds/role edits) |
| `driver` | Own profile, duty status, own assignments, trip milestones, GPS upload, trip expenses |
| `customer` | Own profile, own booking requests, quotes, invoices/payments, active own trip tracking |

## 4. Identity, Authentication & RBAC Requirements

### `AUTH-001` — Registration & Password Storage
- **User Story**: As a customer or staff member, I register/sign in with email or phone and password so my account is protected.
- **Rules**: Passwords >= 10 chars (complexity checked); hashed with Argon2id (`memory >= 64 MiB`, `time >= 3`).
- **Acceptance Criteria**: Plaintext passwords never persisted, returned, or logged; duplicate email/phone returns `409`.

### `AUTH-002` — JWT Access & Rotating Refresh Tokens
- **Rules**: Access token TTL `15m`; opaque refresh token TTL `14d` stored as SHA-256 hash in `auth_sessions` with `family_id`.
- **Acceptance Criteria**: Refreshing issues a new pair and marks prior refresh token rotated. Presenting an already-rotated token revokes the entire `family_id` and returns `401`.

### `AUTH-003` — Login Throttling & Account Lockout
- **Rules**: Redis sliding counter per `(ip, identifier)`.
- **Acceptance Criteria**: 5 consecutive failed logins within 10 minutes locks login for 15 minutes (`429`) and records an `auth.lockout` audit event.

### `AUTH-004` — Account Recovery
- **Acceptance Criteria**: Password reset token is single-use, expires in 15 minutes, stored hashed, and revokes all active `auth_sessions` upon password reset.

### `AUTH-005` — Optional Privileged MFA
- **Acceptance Criteria**: `owner` and `accountant` accounts can enroll TOTP (`pyotp`); when enabled, login requires valid 6-digit TOTP before issuing session tokens.

### `RBAC-001` & `RBAC-002` — Permission Enforcement & Anti-IDOR
- **Acceptance Criteria**: Every route checks role permissions AND resource ownership. Customer A requesting Customer B's booking/invoice/WS returns `403`/`404`. Driver A mutating Driver B's assignment/trip returns `403`.

### `CUST-001` — Guest Enquiry & Authenticated Customer Linking
- **Rules**: Guest booking request creates/matches a `customer_profiles` record and returns a unique booking reference + SHA-256 hashed claim token.
- **Acceptance Criteria**: Registered customer bookings link `customer_id` from JWT; guest claim token allows attaching an enquiry to a newly registered account.

## 5. Non-Functional Requirements (`NFR-*`)
- `NFR-001` Availability & Recovery: `/health/live`, `/health/ready` (checks Postgres + Redis); RPO <= 15m, RTO <= 60m.
- `NFR-002` Performance: Standard API reads p95 < 250ms; GPS batch ingestion p95 < 100ms.
- `NFR-003` Localization Readiness: All DB timestamps in UTC `TIMESTAMPTZ`; currency/timezone configurable via `system_policies`.
- `NFR-004` Observability: `structlog` JSON logs with `X-Correlation-ID` and secret redaction; Sentry error reporting.

## 6. Dependencies & Open Decisions
- Depends on PostgreSQL 16 (`btree_gist`), Redis 7, S3-compatible storage, FCM, and SMTP/SMS providers.
- Unresolved business policies (`BD-01`–`BD-10`) are parameterized in `system_policies`; see [shared-contracts/open-decisions.md](../../shared-contracts/open-decisions.md).
