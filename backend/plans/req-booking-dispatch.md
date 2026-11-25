# Backend Requirements: Services, Bookings, Quotations & Dispatch

## 1. Service Catalogue & Pricing (`SVC-*`)

### `SVC-001` — Configurable Transport Service Categories
- **Scope**: Must seed and support all 8 business categories:
  1. `tour_travel` (multi-destination, itinerary, overnight flag)
  2. `event_transport` (event date/venue, passenger count, return schedule)
  3. `house_shifting_cargo` (cargo volume, floors, elevator availability, loading/unloading)
  4. `airport_transfer` (flight number, terminal, arrival/departure, luggage count)
  5. `corporate_transport` (corporate account link, recurring schedule flag, consolidated billing)
  6. `periodic_rental` (daily/weekly/monthly period, mileage cap, extension rules)
  7. `personal_transport` (pickup, destination, passenger count, special notes)
  8. `custom_service` (dynamic custom fields + custom workflow steps)
- **Acceptance Criteria**: Public `GET /api/v1/public/catalog/services` returns active categories, descriptions, `requires_quote`, and `workflow_steps`.

### `SVC-002` — Pricing Rules & Authoritative Server Estimates
- **Rules**: `pricing_rules` supports `base_minor`, `per_km_minor`, `per_hour_minor`, `waiting_per_hour_minor`, `driver_allowance_minor`, `seasonal_multiplier_bps`, and `corporate_discount_bps`.
- **Acceptance Criteria**: Server computes indicative estimates when configured; client-submitted prices are never trusted or persisted.

## 2. Bookings (`BOOK-*`) & Quotations (`QUOTE-*`)

### `BOOK-001` — Booking Request Creation & Multi-Stop Support
- **User Story**: As a customer or booking manager, I submit a booking with service type, preferred vehicle (optional), pickup, destination, ordered `booking_stops` (`seq_order`), `pickup_at`, `expected_end_at`, passenger/cargo specs, and notes.
- **Acceptance Criteria**: Enforces `expected_end_at > pickup_at`, validates service-specific metadata against the category schema, generates unique reference `VF-YYYYMMDD-XXXX`, and records initial `requested` status in `booking_status_history`.

### `BOOK-002` — Idempotent Submission
- **Acceptance Criteria**: `POST /api/v1/bookings` requires `Idempotency-Key` (UUID). Replaying identical `(actor, key, payload_hash)` returns the original `201`/`200` booking; reusing the key with altered payload returns `409 IDEMPOTENCY_CONFLICT`.

### `BOOK-003` — Availability Check & Zero-Conflict Reservation
- **Rules**: At enquiry time, checks indicative conflicts on `preferred_vehicle_id`. At booking confirmation (`confirmed`), if a specific vehicle is reserved, inserts a `vehicle_schedule_blocks` row (`block_type='booking'`).
- **Acceptance Criteria**: Any overlap with another active booking or maintenance block fails atomically with `409 RESOURCE_CONFLICT`.

### `BOOK-004` — Booking Lifecycle, Reschedule & Cancellation
- **Lifecycle**: `requested` -> `under_review` -> `quoted` -> `quote_accepted` -> `confirmed` -> `assigned` -> `in_progress` -> `completed` -> `closed` (plus `rejected`, `cancelled`, `exception`).
- **Acceptance Criteria**: Rescheduling updates schedule block ranges atomically (rejecting `409` if conflict); cancellation releases active vehicle/driver schedule blocks, evaluates configurable `cancellation_policies`, and logs actor + reason in `audit_logs`.

### `BOOK-005` — Rental Extension Requests
- **Acceptance Criteria**: Extending `expected_end_at` checks `vehicle_schedule_blocks` and `driver_schedule_blocks` for the extended window inside a transaction before updating.

### `QUOTE-001` — Itemized Quotations
- **Rules**: Admin creates itemized quote (`items_json`: base fare, distance, waiting, driver allowance, tolls, tax, discount), `deposit_minor`, `total_minor`, `currency`, `valid_until`, `terms`.
- **Acceptance Criteria**: Customer can accept or reject `sent` quotes before `valid_until`. Expired quotes reject acceptance with `422 QUOTE_EXPIRED`. Accepting transitions booking to `quote_accepted` and supersedes prior quote drafts.

## 3. Dispatch & Resource Allocation (`DISP-*`)

### `DISP-001` — Eligible Resource Lookup & Conflict Flagging
- **Acceptance Criteria**: `GET /api/v1/dispatch/eligible-resources?booking_id=...` returns vehicles and drivers annotated with eligibility (`is_available`, `conflict_reason`, `maintenance_conflict`, `licence_expired`, `capacity_match`).

### `DISP-002` — Atomic Assignment & Reassignment
- **Rules**: Assigning `(booking_id, vehicle_id, driver_id)` runs in one ACID transaction: validates booking is `confirmed`/`assigned`, locks vehicle & driver rows, inserts/updates `vehicle_schedule_blocks` and `driver_schedule_blocks` (`EXCLUDE USING gist`), creates `assignments` row (`pending_ack`), and appends `assignment_history`.
- **Acceptance Criteria**: Concurrent dispatch calls for the same vehicle or driver across two requests produce **exactly 1 success (`201`) and 1 `409 RESOURCE_CONFLICT`**.

### `DISP-003` — Reassignment, Decline & Emergency Breakdown Handoff
- **Acceptance Criteria**: Reassigning marks old assignment `reassigned`, releases its schedule block, claims the new resource block atomically, records reason in `assignment_history` + `audit_logs`, and queues notifications to old driver, new driver, and customer.
