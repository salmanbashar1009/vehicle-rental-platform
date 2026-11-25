# Backend REST API Contracts (`/api/v1`)

All endpoints adhere to [shared-contracts/openapi-conventions.md](../../shared-contracts/openapi-conventions.md). Phase column denotes delivery target (`P1`–`P5`).

## 1. Health, Auth & RBAC
| Phase | Method & Path | Auth / Permission | Summary & Key Rules |
| --- | --- | --- | --- |
| `P1` | `GET /health/live`, `/health/ready` | Public | Liveness & Postgres/Redis readiness (`200` / `503`). |
| `P1` | `POST /api/v1/auth/register` | Public | Customer self-registration; Argon2id hash; returns user + tokens. |
| `P1` | `POST /api/v1/auth/login` | Public (throttled) | Email/phone + password (+ optional TOTP); returns access + refresh token. |
| `P1` | `POST /api/v1/auth/refresh` | Public (refresh token) | Rotates refresh token; reuse revokes entire session family. |
| `P1` | `POST /api/v1/auth/logout`, `/password-reset/*` | Authenticated / Public | Revokes current session or executes single-use password reset. |
| `P1` | `GET /api/v1/auth/me` | Authenticated | Returns current user, roles, permissions, linked customer/driver profile. |
| `P1` | `GET,POST,PATCH /api/v1/users`, `GET /api/v1/roles` | `users.read` / `users.write` | Staff account management & role assignment (`owner` only for role edits). |

## 2. Public Catalogue & Customer Endpoints
| Phase | Method & Path | Auth / Permission | Summary & Key Rules |
| --- | --- | --- | --- |
| `P1` | `GET /api/v1/public/catalog/services` | Public | Lists active 8 service categories, descriptions, workflow metadata. |
| `P1` | `GET /api/v1/public/catalog/vehicles` | Public | Filterable (`category`, `min_seats`, `max_price`, `ac`, `from`, `to`) paginated vehicles + availability indicator. |
| `P1` | `GET /api/v1/public/catalog/vehicles/{id}` | Public | Vehicle details, photos, facilities, indicative pricing. |
| `P1` | `GET,PATCH /api/v1/customers/me` | `customer` | View/update own customer profile; claim guest booking via claim token. |

## 3. Bookings, Quotations & Dispatch
| Phase | Method & Path | Auth / Permission | Summary & Key Rules |
| --- | --- | --- | --- |
| `P1` | `POST /api/v1/bookings` | Public (guest) or Auth | `Idempotency-Key` required; creates booking + stops + indicative availability check. |
| `P1` | `GET /api/v1/bookings` | `bookings.read` or `customer` | Staff sees filtered list; Customer sees **own bookings only**. |
| `P1` | `GET /api/v1/bookings/{id}` | `bookings.read` or owner | Booking detail, stops, timeline, quotes, current assignment (masked/released per policy). |
| `P1` | `POST /api/v1/bookings/{id}/confirm\|reject\|cancel\|reschedule` | `bookings.write` / owner cancel | ACID transition + `vehicle_schedule_blocks` check (`409` on overlap) + audit log. |
| `P1` | `POST /api/v1/bookings/{id}/quotations` | `bookings.write` | Creates/sends itemized quote (`items_json`, `deposit_minor`, `valid_until`). |
| `P1` | `POST /api/v1/quotations/{id}/accept\|reject` | Owner customer | Checks `valid_until > now()` (`422` if expired); transitions booking to `quote_accepted`. |
| `P1` | `GET /api/v1/dispatch/eligible-resources` | `dispatch.read` | Lists eligible vehicles & drivers for `booking_id` with conflict/maintenance flags. |
| `P1` | `POST /api/v1/dispatch/assign` & `/reassign` | `dispatch.write` | Atomic vehicle+driver assignment (`409` on `btree_gist` conflict) + history + alert. |

## 4. Fleet, Drivers, Trips, GPS, Finance & Ops
| Phase | Method & Path | Auth / Permission | Summary & Key Rules |
| --- | --- | --- | --- |
| `P1` | `GET,POST,PATCH /api/v1/vehicles`, `/{id}/images`, `/{id}/calendar` | `fleet.read/write` | Vehicle CRUD, validated S3 image upload, schedule block calendar. |
| `P1` | `GET,POST,PATCH /api/v1/drivers` | `drivers.read/write` | Driver profile & licence management; own availability toggle for driver. |
| `P2` | `GET /api/v1/driver/assignments`, `POST .../ack\|decline` | `driver` (own only) | Driver assignment inbox, acknowledge, decline with reason. |
| `P2` | `POST /api/v1/trips/{id}/milestones\|complete\|incidents` | `driver` (own only) | Workflow step transitions, completion + receipts, urgent incident reports. |
| `P3` | `POST /api/v1/tracking/locations/batch` | `driver` (active trip) | Batch <= 20 GPS points; `403` outside active window; updates Redis + Pub/Sub. |
| `P3` | `GET /api/v1/tracking/fleet/live`, `/bookings/{id}/tracking`, `/trips/{id}/route` | RBAC / active owner | Admin live fleet map, customer active tracking, admin route playback. |
| `P4` | `POST,GET /api/v1/finance/payments\|refunds\|invoices\|expenses` | `finance.*` / owner | Minor-unit ledger, idempotent payments, PDF invoices, expense approvals. |
| `P5` | `/api/v1/maintenance`, `/corporate`, `/reviews`, `/reports`, `/audit` | Domain RBAC | Maintenance locking, corporate accounts, ratings, exports, audit log queries. |
