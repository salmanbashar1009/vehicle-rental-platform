# Domain State Machines

All state transitions are validated server-side and recorded in history/audit tables.

## 1. Booking Lifecycle (`bookings.status`)

- `requested` -> `under_review` | `quoted` | `confirmed` (only if instant-confirm policy enabled) | `rejected` | `cancelled`
- `under_review` -> `quoted` | `rejected` | `cancelled`
- `quoted` -> `quote_accepted` | `quote_rejected` | `quote_expired` | `cancelled`
- `quote_accepted` -> `confirmed` | `cancelled`
- `confirmed` -> `assigned` | `rescheduled` -> `confirmed` | `cancelled`
- `assigned` -> `in_progress` | `confirmed` (if unassigned) | `cancelled`
- `in_progress` -> `completed` | `exception`
- `completed` -> `closed` (after financial review/reconciliation)

## 2. Quotation Lifecycle (`quotations.status`)

- `draft` -> `sent`
- `sent` -> `accepted` | `rejected` | `expired` | `superseded`
- Accepting a quotation requires `valid_until > now()` and atomically supersedes prior drafts.

## 3. Assignment Lifecycle (`assignments.status`)

- `pending_ack` -> `acknowledged` | `declined` | `reassigned` | `cancelled`
- `acknowledged` -> `active` | `reassigned` | `cancelled`
- `active` -> `completed` | `exception_reassigned` | `cancelled`
- Active schedule exclusion block remains held for `pending_ack`, `acknowledged`, and `active`.

## 4. Trip Status Workflow (`trips.status` — Configurable Milestones)

Standard milestones:
1. `assigned`
2. `en_route_to_pickup` *(Authorized GPS tracking window opens)*
3. `arrived_at_pickup`
4. `picked_up`
5. `journey_started`
6. `at_destination`
7. `service_completed` *(Authorized GPS tracking window closes)*
8. `cancelled_or_exception` *(Authorized GPS tracking window closes)*

Service-specific milestone extensions (stored in `service_workflows.steps_json`):
- **House Shifting / Cargo**: inserts `loading_started`, `loading_completed` after `arrived_at_pickup`, and `unloading_started`, `unloading_completed` after `at_destination`.
- **Multi-Stop Tours**: supports repeated `arrived_at_stop_{n}` / `departed_stop_{n}` events in `trip_status_events`.

## 5. Vehicle & Driver Operational Statuses

- **Vehicle**: `available`, `reserved`, `assigned`, `en_route`, `in_service`, `returning`, `maintenance`, `out_of_service`.
- **Driver**: `available`, `assigned`, `on_duty`, `on_break`, `off_duty`, `unavailable`.
