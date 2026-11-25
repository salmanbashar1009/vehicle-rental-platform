# Customer Website Testing & Verification Strategy

## 1. Tooling & Quality Gates
- **Unit & Component Tests**: `dart test` with `jaspr_test` (`testComponents`, `testServer`)
- **Static Analysis**: `dart analyze` (zero warnings/errors) and `dart format --output=none --set-exit-if-changed .`
- **Build & Line Check**: `jaspr build` succeeds; all `.dart`, `.css`, `.html`, `.md` files <= 200 lines.

## 2. Test Categories & Assertions
- **Component & Primitive Tests**:
  - `Button` renders loading spinner & disables clicks while loading; `StatusBadge` applies semantic token classes for all booking/trip statuses; `VehicleCard` renders capacities and indicative price cleanly.
  - `EmptyState` and `ErrorBanner` render action callbacks.
- **SSR & SEO Verification (`testServer`)**:
  - Render `/`, `/services`, `/services/airport-transfer`, `/vehicles`, `/faq`, `/legal/privacy` server-side; assert HTTP 200, `<title>`, `<meta name="description">`, `<link rel="canonical">`, `og:title`, JSON-LD `<script type="application/ld+json">`, and semantic `<main>` content.
  - Verify `/robots.txt` disallows `/dashboard` and `/sitemap.xml` includes public service & vehicle URLs.
  - Unknown route `/non-existent-slug` returns HTTP `404` with Not Found component.
- **Routing & Auth Guard Tests**:
  - Unauthenticated visit to `/dashboard`, `/dashboard/bookings`, `/dashboard/track/123` redirects to `/login?redirect=...`.
- **Booking Wizard & API Contract Tests**:
  - Verify dynamic required fields per service (`house_shifting_cargo` requires floor/cargo info; `airport_transfer` requires flight/terminal).
  - Verify `POST /api/v1/bookings` attaches `Idempotency-Key` UUID and renders friendly conflict alert on `409 RESOURCE_CONFLICT`.
- **Tracking & Portal Tests**:
  - Mock WebSocket `vehicle.location` + `freshness` frames (`live`, `stale`, `offline`) and verify map marker/badge updates; verify tracking view displays safe notice when booking is completed or unauthorized.
- **Responsive & Accessibility Checks**:
  - Verify viewport CSS rules at `375px`, `768px`, `1280px`; verify ARIA labels on icon buttons and keyboard focus visibility.

## 3. Requirement-to-Test Traceability
| Req IDs | Test Suite(s) |
| --- | --- |
| `WEB-001`, `WEB-007` | `test/seo_ssr_test.dart` |
| `WEB-002`, `WEB-003` | `test/components_test.dart`, `test/catalog_filter_test.dart` |
| `WEB-004` | `test/booking_wizard_test.dart` |
| `WEB-005` | `test/auth_portal_test.dart` |
| `WEB-006` | `test/tracking_view_test.dart` |
