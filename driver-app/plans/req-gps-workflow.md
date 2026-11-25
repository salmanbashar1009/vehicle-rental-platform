# Driver App Requirements: Trip Workflow, GPS, Nav & Completion

## 1. Configurable Trip Status Workflow (`DRV-TRIP-*`)
- **`DRV-TRIP-001` Standard Lifecycle**:
  1. `assigned`
  2. `en_route_to_pickup` *(opens authorized GPS window)*
  3. `arrived_at_pickup`
  4. `picked_up`
  5. `journey_started`
  6. `at_destination`
  7. `service_completed` *(closes authorized GPS window)*
  8. `cancelled_or_exception` *(closes authorized GPS window)*
- **`DRV-TRIP-002` Service-Configurable Milestones**:
  - Renders dynamic steps from backend `service_workflows` (e.g., House Shifting inserts `loading_started` / `loading_completed` and `unloading_started` / `unloading_completed`; multi-stop tours show ordered stop arrival/departure buttons).
  - Every milestone tap triggers a stationary confirmation sheet before submitting.
- **`DRV-TRIP-003` Offline Action Queueing**:
  - If offline when confirming a milestone, stores action in SQLite `pending_trip_actions` with UTC timestamp + `Idempotency-Key`, shows `"Pending Sync"` pill, and replays strictly FIFO on reconnect.

## 2. Authorized GPS Location Sharing (`DRV-GPS-*`)
- **`DRV-GPS-001` Strict Window Gating**: Starts ONLY when trip enters `en_route_to_pickup` and stops immediately when trip reaches `service_completed`, `cancelled_or_exception`, or assignment is revoked/reassigned.
- **`DRV-GPS-002` OS Background Compliance**: Captures `lat`, `lng`, `accuracy_m`, `speed_mps`, `heading_deg`, UTC `recorded_at`, and `assignment_id` via Android Foreground Service (persistent notification) and iOS Background Location mode.
- **`DRV-GPS-003` Offline GPS Buffering**: Buffers points locally in SQLite during cellular dead zones and flushes in chronological batches (`<= 20` pts) with exponential backoff.
- **`DRV-GPS-004` Health & Interruption Visibility**: Detects `gps_disabled`, `permission_denied`, `network_offline`, and `stale` states; displays prominent status pill to driver and signals backend interruption.

## 3. Navigation, Communication, Completion & Incidents (`DRV-OPS-*`)
- **`DRV-OPS-001` Map & External Navigation**: Shows ordered stops on `flutter_map` (OSM tiles) and opens pickup, intermediate stops, or destination in external installed navigation apps via OS URL intent.
- **`DRV-OPS-002` Approved Calling & Urgent Incidents**: One-tap approved phone call to customer or dispatch center; report `breakdown`, `accident`, `medical`, `security`, or `customer_dispute` with photos, GPS coordinates, and notes.
- **`DRV-OPS-003` Trip Completion**: Captures completion time, final odometer, actual distance, waiting minutes, extra charges, trip expenses + receipt photos, service notes, and optional customer confirmation/signature; transitions booking for admin review.
