# Backend Database Schema & Migration Design

Engine: **PostgreSQL 16** (`pgcrypto`, `btree_gist`). Conventions: `UUID` PKs, UTC `TIMESTAMPTZ` (`created_at`, `updated_at`), `deleted_at TIMESTAMPTZ NULL` for soft-deletable entities, `BIGINT` minor units + `VARCHAR(3) currency`.

## 1. Identity, RBAC & Customers
- `users`: `id`, `email` (UNIQUE nullable), `phone` (UNIQUE nullable), `full_name`, `password_hash`, `is_active`, `mfa_enabled`, `mfa_secret_enc`, `failed_login_count`, `locked_until`, `deleted_at`. Check: `email IS NOT NULL OR phone IS NOT NULL`.
- `roles` (`id`, `slug` UNIQUE, `name`), `permissions` (`id`, `code` UNIQUE, `description`), `user_roles` (`user_id`, `role_id` PK), `role_permissions` (`role_id`, `permission_id` PK).
- `auth_sessions`: `id`, `user_id` FK, `family_id`, `refresh_token_hash` UNIQUE, `expires_at`, `rotated_at`, `revoked_at`, `user_agent`, `ip_address`.
- `password_reset_tokens`: `id`, `user_id` FK, `token_hash` UNIQUE, `expires_at`, `used_at`.
- `corporate_accounts`: `id`, `company_name`, `tax_id`, `billing_cycle`, `credit_limit_minor`, `currency`, `negotiated_discount_bps`, `is_active`.
- `customer_profiles`: `id`, `user_id` UNIQUE FK NULL, `corporate_id` FK NULL, `customer_type` (`individual`|`corporate`), `full_name`, `email`, `phone`, `notes`, `deleted_at`.

## 2. Services, Fleet & Drivers
- `service_categories`: `id`, `slug` UNIQUE, `name`, `description`, `requires_quote`, `is_active`, `display_order`.
- `service_workflows`: `id`, `service_category_id` UNIQUE FK, `steps_json` (ordered milestone definitions), `form_schema_json`.
- `pricing_rules`: `id`, `service_category_id` FK, `vehicle_category`, `base_minor`, `per_km_minor`, `per_hour_minor`, `waiting_per_hour_minor`, `driver_allowance_minor`, `seasonal_multiplier_bps`, `currency`, `effective_range TSTZRANGE`.
- `vehicles`: `id`, `plate_number` UNIQUE, `category`, `make`, `model`, `year`, `seat_capacity`, `luggage_capacity`, `cargo_volume_m3`, `fuel_type`, `facilities_json`, `status`, `odometer_km`, `ownership_type`, `is_public`, `deleted_at`.
- `vehicle_images` (`id`, `vehicle_id` FK, `object_key`, `is_primary`, `sort_order`), `vehicle_documents` (`id`, `vehicle_id` FK, `doc_type`, `doc_number`, `file_key`, `issued_at`, `expires_at`).
- `maintenance_records`: `id`, `vehicle_id` FK, `maint_type`, `description`, `provider_name`, `scheduled_range TSTZRANGE`, `cost_minor`, `currency`, `odometer_km`, `receipt_key`, `status`.
- **`vehicle_schedule_blocks`**: `id`, `vehicle_id` FK, `block_type` (`booking`|`maintenance`|`out_of_service`), `source_id`, `time_range TSTZRANGE`, `is_active BOOLEAN`.
  - **Constraint**: `EXCLUDE USING gist (vehicle_id WITH =, time_range WITH &&) WHERE (is_active = true)`
- `driver_profiles`: `id`, `user_id` UNIQUE FK, `licence_number` UNIQUE, `licence_classes_json`, `licence_expiry`, `emergency_contact_name`, `emergency_contact_phone`, `photo_key`, `employment_status`, `availability_status`, `deleted_at`.
- **`driver_schedule_blocks`**: `id`, `driver_id` FK, `block_type` (`assignment`|`leave`|`unavailable`), `source_id`, `time_range TSTZRANGE`, `is_active BOOLEAN`.
  - **Constraint**: `EXCLUDE USING gist (driver_id WITH =, time_range WITH &&) WHERE (is_active = true)`

## 3. Bookings, Quotations, Dispatch, Trips & Tracking
- `bookings`: `id`, `reference` UNIQUE, `customer_id` FK, `service_category_id` FK, `preferred_vehicle_id` FK NULL, `status`, `pickup_at`, `expected_end_at`, `passenger_count`, `luggage_count`, `cargo_details_json`, `service_metadata_json`, `special_instructions`, `internal_notes`, `tracking_enabled`, `claim_token_hash`. Check: `expected_end_at > pickup_at`.
- `booking_stops` (`id`, `booking_id` FK, `seq_order`, `stop_type`, `address`, `lat`, `lng`), `booking_status_history` (`id`, `booking_id` FK, `from_status`, `to_status`, `changed_by`, `reason`, `created_at`).
- `quotations`: `id`, `booking_id` FK, `version`, `items_json`, `subtotal_minor`, `discount_minor`, `tax_minor`, `total_minor`, `deposit_minor`, `currency`, `valid_until`, `terms`, `status`, `responded_at`.
- `assignments`: `id`, `booking_id` FK, `vehicle_id` FK, `driver_id` FK, `status`, `assigned_by` FK, `acknowledged_at`, `decline_reason`, `is_current BOOLEAN` (partial unique index on `booking_id WHERE is_current = true`).
- `assignment_history`: `id`, `assignment_id` FK, `booking_id` FK, `vehicle_id` FK, `driver_id` FK, `action`, `actor_id`, `reason`, `created_at`.
- `trips`: `id`, `assignment_id` UNIQUE FK, `status`, `started_at`, `completed_at`, `start_odometer`, `end_odometer`, `actual_distance_km`, `waiting_minutes`, `extra_charges_minor`, `currency`, `signature_key`, `completion_notes`, `admin_reviewed_by`.
- `trip_status_events` (`id`, `trip_id` FK, `milestone`, `occurred_at`, `lat`, `lng`, `notes`, `idempotency_key` UNIQUE).
- `location_points` (`id`, `trip_id` FK, `driver_id` FK, `lat`, `lng`, `accuracy_m`, `speed_mps`, `heading_deg`, `recorded_at`), indexed `(trip_id, recorded_at DESC)`.
- `incident_reports` (`id`, `trip_id` FK, `driver_id` FK, `category`, `severity`, `description`, `lat`, `lng`, `photos_json`, `status`, `resolved_by`).

## 4. Finance, Notifications, Audit & Policies
- `invoices` (`id`, `booking_id` FK, `invoice_number` UNIQUE, `agreed_minor`, `extra_minor`, `discount_minor`, `tax_minor`, `total_minor`, `currency`, `status`, `issued_at`).
- `payments` (`id`, `booking_id` FK, `invoice_id` FK NULL, `payment_type`, `method`, `amount_minor`, `currency`, `transaction_ref`, `reconciliation_status`, `idempotency_key` UNIQUE, `recorded_by`).
- `refunds` (`id`, `payment_id` FK, `booking_id` FK, `amount_minor`, `currency`, `reason`, `status`, `approved_by`, `idempotency_key` UNIQUE).
- `expenses` (`id`, `booking_id` FK NULL, `vehicle_id` FK NULL, `driver_id` FK NULL, `category`, `amount_minor`, `currency`, `incurred_at`, `receipt_key`, `status`, `reviewed_by`).
- `notifications`, `notification_outbox`, `reviews`, `audit_logs`, `idempotency_keys`, `system_policies`.
