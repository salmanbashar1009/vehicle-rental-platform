# WebSocket Real-Time Protocol

## Connection & Authentication

- Endpoint: `wss://<host>/api/v1/ws`
- Auth: Short-lived JWT access token sent via `Authorization: Bearer <token>` header (desktop/mobile) or initial authenticated `auth` handshake frame / `Sec-WebSocket-Protocol` subprotocol token (never in URL query string to prevent access-log leakage).
- Connection closes with `4001 Unauthorized` if authentication fails or token expires without refresh.

## Channels & Authorization

| Channel Pattern | Subscribers Allowed | Events Delivered |
| --- | --- | --- |
| `admin:fleet` | Staff with `tracking.read` / `dispatch.read` | `vehicle.location`, `trip.status`, `dispatch.changed`, `alert.raised` |
| `booking:{booking_id}` | Staff OR booking owner `customer_id` (only while tracking enabled) | `trip.status`, `vehicle.location` (masked driver PII), `assignment.updated` |
| `driver:{driver_id}` | Authenticated driver matching `driver_id` | `assignment.created`, `assignment.updated`, `assignment.cancelled` |

Subscription requests (`{"type":"subscribe","channel":"..."}`) are server-authorized on every subscribe frame and re-checked on assignment/booking termination.

## Message Envelope

```json
{
  "type": "vehicle.location",
  "channel": "admin:fleet",
  "event_id": "01936400-1122-7abc-8def-001122334455",
  "timestamp": "2026-11-25T10:15:30Z",
  "payload": {
    "vehicle_id": "uuid",
    "assignment_id": "uuid",
    "lat": 23.8103,
    "lng": 90.4125,
    "accuracy_m": 8.5,
    "speed_mps": 11.2,
    "heading_deg": 145.0,
    "recorded_at": "2026-11-25T10:15:28Z",
    "freshness": "live"
  }
}
```

## Heartbeat, Reconnection & Freshness

- **Heartbeat**: Client sends `{"type":"ping"}` every 25s; server replies `{"type":"pong"}`. Idle sockets > 60s without ping are closed cleanly.
- **Reconnection**: Clients use exponential backoff with jitter (1s, 2s, 4s, 8s, max 30s) and fetch REST state snapshot on reconnect to heal missed events.
- **Freshness Thresholds**:
  - `live`: `now - recorded_at <= 60s`
  - `stale`: `60s < now - recorded_at <= 300s`
  - `offline`: `now - recorded_at > 300s` or explicit GPS/network interruption flag from driver app.
