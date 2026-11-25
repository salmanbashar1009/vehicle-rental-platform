# Backend Requirements: Fleet, Maintenance, Drivers, Trips & GPS

## 1. Fleet & Document Management (`FLEET-*`)

### `FLEET-001` — Vehicle Profiles & Capacity Specs
- **Acceptance Criteria**: CRUD for vehicles (`plate_number` unique, `category`, `make`, `model`, `year`, `seat_capacity`, `luggage_capacity`, `cargo_volume_m3`, `fuel_type`, `facilities[]`, `odometer_km`, `status`). Duplicate `plate_number` returns `409`.
- **Images**: Upload up to 10 images per vehicle via S3 after magic-byte validation (`image/jpeg`, `image/png`, `image/webp`, `<= 10 MB`).

### `FLEET-002` — Vehicle Documents & Expiry Reminders
- **Rules**: Tracks `registration`, `insurance`, `fitness`, `permit`, `other` with `doc_number`, `issued_at`, `expires_at`, and private S3 `file_key`.
- **Acceptance Criteria**: Scheduled worker emits `fleet.doc_expiring` alerts at `30d`, `7d`, and `0d` before `expires_at`.

### `FLEET-003` — Vehicle Availability Calendar & Operational Status
- **Statuses**: `available`, `reserved`, `assigned`, `en_route`, `in_service`, `returning`, `maintenance`, `out_of_service`.
- **Acceptance Criteria**: `GET /api/v1/vehicles/{id}/calendar?from=...&to=...` merges `vehicle_schedule_blocks` (`booking`, `maintenance`, `out_of_service`) accurately.

## 2. Maintenance Management (`MAINT-*`)
- **`MAINT-001`**: Record preventive schedules, repairs, tyre, battery, and oil-change logs with `scheduled_range TSTZRANGE`, `provider_name`, `cost_minor`, `currency`, `odometer_km`, and receipt attachment.
- **`MAINT-002`**: Creating or activating a maintenance window inserts an active `vehicle_schedule_blocks` row (`block_type='maintenance'`). If an existing confirmed booking overlaps, API warns/blocks unless admin triggers emergency reassignment (`409` by default).

## 3. Driver Management (`DRV-*`)
- **`DRV-001`**: Driver profiles link 1:1 to `users` and store `licence_number` (unique), `licence_classes[]`, `licence_expiry`, `emergency_contact_name`, `emergency_contact_phone`, `employment_status`, and `availability_status` (`available`, `assigned`, `on_duty`, `on_break`, `off_duty`, `unavailable`).
- **`DRV-002`**: Dispatch blocks drivers whose `licence_expiry <= today` or whose `driver_schedule_blocks` overlap the booking window (`409`).
- **`DRV-003`**: Drivers may toggle only `available`, `on_break`, `off_duty` — blocked (`409`) while an `active` trip is in progress.

## 4. Trip Execution, Milestones & Incidents (`TRIP-*`)
- **`TRIP-001`**: Driver endpoints return only assignments where `driver_id == current_driver.id`. Driver can `acknowledge` or `decline` (mandatory reason; alerts dispatcher immediately).
- **`TRIP-002`**: Configurable workflow milestones (`assigned` -> `en_route_to_pickup` -> `arrived_at_pickup` -> `picked_up` -> `journey_started` -> `at_destination` -> `service_completed`, plus service-specific steps like `loading_started`/`loading_completed` or `arrived_at_stop_N`). Every transition validates order against `service_workflows` and records UTC `occurred_at` + optional GPS coords in `trip_status_events` with `Idempotency-Key`.
- **`TRIP-003`**: Trip completion records `completed_at`, `end_odometer`, `actual_distance_km`, `waiting_minutes`, `extra_charges_minor`, `notes`, optional customer signature S3 key, and moves booking to `completed` (pending admin financial review -> `closed`).
- **`TRIP-004`**: Incident reporting (`breakdown`, `accident`, `medical`, `security`, `customer_dispute`) accepts severity, coordinates, description, and photos; emits immediate WebSocket + push alert to `admin:fleet`.

## 5. GPS Tracking, Privacy & Retention (`GPS-*`)
- **`GPS-001`**: `POST /api/v1/tracking/locations/batch` accepts <= 20 points (`lat`, `lng`, `accuracy_m`, `speed_mps`, `heading_deg`, `recorded_at`, `assignment_id`) with `Idempotency-Key`.
- **`GPS-002`**: Rejects points (`403 TRACKING_WINDOW_CLOSED`) unless `assignment.driver_id == actor.driver_id` AND `trip.status` is in the active authorized window (`en_route_to_pickup` .. `at_destination`).
- **`GPS-003`**: Latest coordinate stored in Redis hash `vehicle:latest:{vehicle_id}` (TTL 600s) and published to Redis Pub/Sub (`admin:fleet`, `booking:{id}`). Freshness computed server-side: `live` (`<= 60s`), `stale` (`61s..300s`), `offline` (`> 300s` or driver interruption event).
- **`GPS-004`**: Sampled trajectory points (`>= 15m` or `>= 15s` delta) persist asynchronously to `location_points`. Customer access is restricted to active own booking (`GET /api/v1/bookings/{id}/tracking`); historical playback is restricted to authorized admin roles and purged after `gps_retention_days`.
