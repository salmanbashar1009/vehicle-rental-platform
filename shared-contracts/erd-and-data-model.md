# Entity Relationship & Data Model Design

All primary keys use `UUID` (v7/v4). All timestamps use `TIMESTAMPTZ` stored in UTC. Monetary amounts use `BIGINT` minor units (e.g., cents/paisa) or `NUMERIC(14,2)` alongside explicit 3-char ISO-4217 `currency`. Soft deletes use `deleted_at TIMESTAMPTZ NULL`.

## Domain Entity Relationships

```
users 1--* user_roles *--1 roles 1--* role_permissions *--1 permissions
users 1--0..1 customer_profiles *--0..1 corporate_accounts
users 1--0..1 driver_profiles

vehicles 1--* vehicle_documents
vehicles 1--* maintenance_records
vehicles 1--* vehicle_schedule_blocks  (bookings + maintenance exclusion)

service_categories 1--* service_workflows
service_categories 1--* pricing_rules

bookings *--1 customer_profiles
bookings *--1 service_categories
bookings *--0..1 vehicles (preferred_vehicle_id)
bookings 1--* booking_stops
bookings 1--* quotations
bookings 1--* booking_status_history
bookings 1--* assignments

assignments *--1 bookings
assignments *--1 vehicles
assignments *--1 driver_profiles
assignments 1--* assignment_history
assignments 1--0..1 trips

trips 1--* trip_status_events
trips 1--* location_points
trips 1--* incident_reports
trips 1--* reviews

bookings 1--* invoices
bookings 1--* payments 1--* refunds
bookings/vehicles/drivers 0..1--* expenses
users 1--* notifications
users 1--* audit_logs
```

## Critical Integrity Constraints

1. **Zero Double-Booking Vehicles (`vehicle_schedule_blocks`)**:
   - Columns: `id`, `vehicle_id`, `block_type` (`booking` | `maintenance` | `out_of_service`), `source_id`, `time_range TSTZRANGE`, `is_active BOOLEAN`.
   - Constraint (requires `btree_gist`):
     `EXCLUDE USING gist (vehicle_id WITH =, time_range WITH &&) WHERE (is_active = true)`
   - Both confirmed booking reservations and active maintenance schedules insert/update rows in `vehicle_schedule_blocks` inside the same DB transaction.
2. **Zero Double-Booking Drivers (`driver_schedule_blocks`)**:
   - Columns: `id`, `driver_id`, `block_type` (`assignment` | `leave` | `unavailable`), `source_id`, `time_range TSTZRANGE`, `is_active BOOLEAN`.
   - Constraint:
     `EXCLUDE USING gist (driver_id WITH =, time_range WITH &&) WHERE (is_active = true)`
3. **Immutable Financial Ledger**:
   - `payments` and `refunds` rows are append-only (`UPDATE` forbidden on amount/currency; status changes or reversals insert ledger/adjustment records) with unique `idempotency_key`.
4. **Immutable Audit Trail**:
   - `audit_logs` stores `actor_id`, `actor_role`, `action`, `resource_type`, `resource_id`, `before_state JSONB`, `after_state JSONB`, `reason`, `correlation_id`, `created_at`. Application DB role grants `INSERT, SELECT` only (no `UPDATE`/`DELETE`).
