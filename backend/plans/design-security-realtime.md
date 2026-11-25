# Backend Security, RBAC & Real-Time Architecture

## 1. RBAC Permission Matrix (Backend-Enforced)
| Resource / Action | Owner | Booking Mgr | Fleet Mgr | Dispatcher | Accountant | Support | Driver | Customer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Users, Roles & Policies | RW | - | - | - | - | - | - | - |
| Bookings & Quotations | RW | RW | R | R | R | R + Notes | - | Own RW* |
| Vehicles & Docs | RW | R | RW | R | R | R | Assigned R | Public R |
| Maintenance Windows | RW | R | RW | R | R (Cost) | - | - | - |
| Drivers & Licences | RW | R | R | R | - | R | Own R/Avail | - |
| Dispatch & Reassign | RW | R | R | RW | - | R | Own Ack | - |
| Trips & Incidents | RW | R | R | R | - | R + Notes | Own RW | Own Status |
| Live GPS & Playback | RW | R | R | R | - | R | Upload Own | Own Active |
| Payments & Refunds | RW | R (No Ref) | - | - | RW | R (No Ref) | - | Own Pay/Inv |
| Expenses | RW | - | R | - | RW (Approve) | - | Own Submit | - |
| Reports & Audit Logs | RW | Ops R | Fleet R | Ops R | Fin R | - | - | - |

*\*Customer `Own RW` covers creating requests, accepting/rejecting quotes, and requesting cancel/reschedule.*

## 2. Token Rotation & Reuse-Detection Flow
```
Client ──(POST /auth/refresh {refresh_token})──▶ AuthService
  1. Hash token -> lookup auth_sessions WHERE refresh_token_hash = hash
  2. If rotated_at IS NOT NULL (REUSE DETECTED!):
       UPDATE auth_sessions SET revoked_at = now() WHERE family_id = session.family_id
       -> Audit("auth.refresh_reuse_revoked") -> return 401
  3. If revoked_at IS NOT NULL OR expires_at < now(): return 401
  4. Generate new access (15m) + new refresh token; mark old rotated_at = now()
```

## 3. WebSocket & GPS Real-Time Pipeline
- **Handshake**: `wss://<host>/api/v1/ws` authenticates JWT via `Authorization` header or initial auth handshake frame (never URL query string). Rejects invalid/expired auth with `4001`.
- **Subscriptions**:
  - `admin:fleet`: requires `tracking.read` or `dispatch.read`.
  - `booking:{id}`: requires staff `tracking.read` OR `booking.customer_id == current_customer.id` AND `booking.tracking_enabled == true` AND trip is active.
  - `driver:{id}`: requires `current_driver.id == id`.
- **Heartbeat**: Ping/pong every 25s; disconnect idle sockets after 60s.
- **GPS Ingestion (`POST /api/v1/tracking/locations/batch`)**:
  1. Validate `driver` owns `assignment_id` and `trip.status` in (`en_route_to_pickup` .. `at_destination`).
  2. Redis token bucket per assignment (reject abuse with `429`).
  3. Update Redis hash `vehicle:latest:{vehicle_id}` (TTL 600s) with `lat, lng, accuracy_m, speed_mps, heading_deg, recorded_at`.
  4. Publish event to Redis Pub/Sub channels `admin:fleet` and `booking:{booking_id}`.
  5. Filter meaningful trajectory delta (`>= 15m` or `>= 15s` since last persisted) and queue batch insert into `location_points`.

## 4. Background Worker Jobs (`app/workers/`)
- **Outbox Worker (every 2s)**: Processes `notification_outbox` rows via FCM/SMTP/SMS adapters with exponential backoff + max 5 retries + dead-letter flag.
- **Monitoring Worker (every 5m)**: Scans active trips in Redis; if `now - recorded_at > 300s`, marks freshness `offline` and emits `tracking.interrupted` alert to `admin:fleet`.
- **Daily Housekeeping (02:00 UTC)**: Expires quotes (`valid_until < now()`), sends `30d`/`7d`/`0d` document & licence expiry reminders, purges `location_points` older than `gps_retention_days`.
