# Backend Requirements: Finance, CRM, Notifications, Reports & Security

## 1. Financial Management (`FIN-*`)
- **`FIN-001` Minor-Unit Precision**: All amounts stored as `BIGINT` (`amount_minor`) + 3-letter ISO-4217 `currency`. Zero IEEE-754 float math anywhere in backend services or DB queries.
- **`FIN-002` Immutable Payment & Refund Ledger**:
  - `POST /api/v1/finance/payments` records `payment_type` (`deposit`, `partial`, `full`, `extra_charge`), `method` (`cash`, `bank_transfer`, `card`, `online_gateway`), `amount_minor`, `transaction_ref`, `reconciliation_status` (`pending`, `reconciled`, `disputed`), and mandatory `Idempotency-Key`.
  - Refunds (`POST /api/v1/finance/refunds`) require `accountant` or `owner` role, link to original payment/booking, require reason, and log before/after in `audit_logs`.
- **`FIN-003` Cash Flow vs Recognized Booking Value**:
  - Booking financial summary computes separately: `quoted_minor`, `agreed_minor`, `extra_charges_minor`, `discount_minor`, `paid_minor` (reconciled/received cash), `refunded_minor`, `outstanding_minor` (`agreed + extra - discount - paid + refunded`).
- **`FIN-004` Invoices & Receipts**: Generate sequential invoice numbers (`INV-YYYY-XXXXXX`), line items, tax breakdown, and downloadable PDF receipt/invoice stored or streamed cleanly.
- **`FIN-005` Trip & Operating Expenses**: Drivers (for own active/completed trips) and Fleet/Accountant staff log `fuel`, `toll`, `parking`, `driver_allowance`, `maintenance`, `other` with receipt image S3 key; Accountant/Owner approves or rejects with notes.

## 2. CRM & Corporate Accounts (`CRM-*`)
- **`CRM-001`**: Support `individual` and `corporate` customer types. `corporate_accounts` stores `company_name`, `tax_id`, `billing_cycle`, `credit_limit_minor`, `negotiated_discount_bps`, and account notes.
- **`CRM-002`**: Track customer communication logs (`call`, `email`, `whatsapp`, `note`), booking history, repeat-customer count, and outstanding corporate/individual balances.

## 3. Event-Driven Notifications (`NOTIF-*`)
- **`NOTIF-001`**: Transactional `notification_outbox` emits events for: `booking.created`, `quote.sent`, `booking.confirmed`, `assignment.created`, `assignment.reassigned`, `trip.milestone`, `trip.completed`, `payment.received`, `maintenance.due`, `doc.expiring`, `incident.urgent`.
- **`NOTIF-002`**: Pluggable channel adapters: `in_app` (DB + WS), `push` (FCM), `email` (SMTP), `sms` / `whatsapp` (feature-flagged adapter interfaces). Tracks delivery attempts, deduplication key, and retry backoff.

## 4. Reports (`RPT-*`) & Reviews (`REV-*`)
- **`RPT-001`**: Reports for period bookings, cash flow vs recognized revenue, expenses, vehicle utilization %, driver completed jobs & ratings, cancellation rate, service popularity, and customer retention.
- **`RPT-002`**: Asynchronous CSV and PDF export endpoints guarded by RBAC (`accountant`/`owner` for financial exports).
- **`REV-001`**: Customer submits 1–5 ratings (`overall`, `driver`, `vehicle`, `service`) + comment once per `completed`/`closed` booking; Admin can moderate (`published`/`hidden`).

## 5. Cybersecurity & Audit (`SEC-*`)
- **`SEC-001` Audit Trail**: Immutable `audit_logs` records all logins/lockouts, role changes, booking edits/cancellations, assignments/reassignments, vehicle/driver status overrides, and financial/refund actions (`actor_id`, `role`, `action`, `resource`, `before_json`, `after_json`, `reason`, `correlation_id`).
- **`SEC-002` API Hardening**: Strict Pydantic schemas (`extra="forbid"`), parameterized SQLAlchemy queries only, request body size limit, security headers (`X-Content-Type-Options`, `X-Frame-Options`, `HSTS`), explicit CORS allowlist, magic-byte upload checks.
- **`SEC-003` Safe Error Responses**: Global exception handler maps internal errors to `500 INTERNAL_ERROR` + `correlation_id` without stack traces or SQL leaks.
