# Admin Dashboard Requirements (Entry Point)

## 1. Purpose & Target Users
Central operational desktop application for the company owner and authorized staff (`owner`, `booking_manager`, `fleet_manager`, `dispatcher`, `accountant`, `customer_support`) running on Windows.

## 2. Supplementary Requirement Specs
- [req-modules.md](req-modules.md) — Detailed functional requirements, acceptance criteria, and edge cases for all **12 Admin Modules** (`ADM-DASH-001` through `ADM-RBAC-001`).

## 3. Core Desktop Platform, UX & Security Requirements

### `ADM-001` — Staff Authentication & Session Lifecycle
- **User Story**: As an employee, I sign in with my company credentials (and TOTP MFA when required) so I only see and operate modules permitted for my role.
- **Acceptance Criteria**:
  - Refresh tokens stored securely via `flutter_secure_storage`; expired/revoked sessions return to Login cleanly.
  - Navigation rail and routes reflect backend permissions from `/api/v1/auth/me`, while backend `403` responses render an explicit authorization banner.

### `ADM-002` — Responsive Windows Desktop Shell & Shortcuts
- **Acceptance Criteria**:
  - Collapsible left sidebar (`240px` expanded <-> `72px` icon rail) preserving active route.
  - Layout adapts cleanly across `1024x700`, `1440x900`, and `2560x1440` without `RenderFlex` overflow.
  - Keyboard shortcuts: `Ctrl+K` (global booking/vehicle/customer search), `F5` (refresh current view), `Esc` (close active slide-over drawer/dialog).

### `ADM-003` — Enterprise Data Tables & Explicit View States
- **Acceptance Criteria**:
  - Every list module supports search, multi-facet filters, column sorting, and server-side pagination (`page`, `page_size`).
  - Every screen implements distinct **Loading** (skeleton), **Loaded**, **Empty** (explanation + "Clear filters" or "+ Create" CTA), and **Error** (human message + correlation ID + Retry) states.

### `ADM-004` — Destructive & Sensitive Action Confirmations
- **Acceptance Criteria**: Rejecting bookings, cancelling bookings, reassigning active trips, approving refunds, and deactivating vehicles/users open a confirmation dialog capturing an audit `reason` before calling the API.

### `ADM-005` — Open Mapping (`flutter_map`)
- **Acceptance Criteria**: Uses `flutter_map` + `latlong2` with configurable OSM-compatible tile URL, optional API key, and visible attribution footer. Zero Google Maps Flutter SDK dependency.

## 4. Dependencies & Assumptions
- Consumes FastAPI `/api/v1/*` and `/api/v1/ws` documented in [shared-contracts/api-contract-strategy.md](../../shared-contracts/api-contract-strategy.md).
- Assumes Windows 10/11 desktop display targets (`>= 1024px` width) and network connectivity with automatic WebSocket reconnection.
