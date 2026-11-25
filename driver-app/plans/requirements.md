# Driver Application Requirements (Entry Point)

## 1. Purpose & Design Philosophy
Provide drivers with a reliable, low-cognitive-load Android and iOS application for managing assigned jobs, updating configurable service milestones, navigating to stops, submitting completion/incident details, and sharing authorized live GPS location.

## 2. Supplementary Requirement Specs
- [req-gps-workflow.md](req-gps-workflow.md) — Configurable trip workflows, offline sync, authorized background GPS, navigation, communication, incidents, and completion (`DRV-TRIP-*`, `DRV-GPS-*`, `DRV-OPS-*`).

## 3. Core Authentication, Permissions, Home & Assignments

### `DRV-AUTH-001` — Driver Authentication & Recovery
- **Acceptance Criteria**: Email/phone + password sign-in, rotating refresh token stored in `flutter_secure_storage`, logout revoking backend session, and account recovery flow.

### `DRV-AUTH-002` — Driver Profile & Licence Status
- **Acceptance Criteria**: Displays driver photo, name, phone, emergency contact, vehicle eligibility, licence number/classes, and expiry warning badge when `licence_expiry <= 30 days`.

### `DRV-AUTH-003` — OS Permission Rationale & Recovery
- **Rules**: Android/iOS location (`WhenInUse` + `Always`/Background) and notification permissions MUST be preceded by an in-app explanation screen describing why location is collected only during active jobs.
- **Acceptance Criteria**: Denied permissions surface a clear banner with one-tap deep-link to OS App Settings and report `tracking_unavailable` to the backend.

### `DRV-HOME-001` — Driver Home Screen
- **Acceptance Criteria**:
  - Duty/availability toggle (`available`, `on_break`, `off_duty`), disabled with explanation while an active trip is in progress.
  - Highlights **Current Assignment** card (with one-tap primary action), **Upcoming Assignments**, **Today's Completed Count**, and **Operational Alerts**.

### `DRV-ASSIGN-001` & `DRV-ASSIGN-002` — Assignment Alerts, Details & Acknowledgement
- **Acceptance Criteria**:
  - Receives FCM push + real-time alert when a job is assigned, updated, reassigned, or cancelled.
  - Detail view displays booking reference, approved customer contact, assigned vehicle + plate, pickup address, destination, ordered stops, schedule, and service instructions.
  - Driver can **Acknowledge** (`pending_ack` -> `acknowledged`) or **Unable to Attend / Request Assistance** (mandatory reason -> notifies dispatcher immediately).
