# Customer Website Requirements (Entry Point)

## 1. Purpose & Scope
Provide a premium, conversion-focused, SEO-crawlable public website and secure customer self-service portal backed by the FastAPI modular monolith.

## 2. Supplementary Requirement Specs
- [req-pages-flows.md](req-pages-flows.md) — Complete 22-page route specifications, service-dynamic form fields, portal flows, and edge cases.

## 3. Functional Requirements (`WEB-*`)

### `WEB-001` — Server-Side Rendering & Search Crawlability
- **User Story**: As a prospective customer searching Google for airport transfers or tour vans, I land on fast, fully rendered service and vehicle pages.
- **Acceptance Criteria**: All marketing, service, vehicle catalogue, FAQ, and legal pages render full semantic HTML server-side via Jaspr (`curl` shows complete copy, headings, prices, and links without JS).

### `WEB-002` — Responsive Multi-Device Experience
- **Rules**: Support `375px` mobile, `768px` tablet, `1024px+` desktop using tokens from [shared-contracts/design-tokens.md](../../shared-contracts/design-tokens.md).
- **Acceptance Criteria**: Mobile collapsible drawer nav; zero horizontal overflow; touch-friendly controls (`>= 44px` tap targets).

### `WEB-003` — Service & Vehicle Catalogue Discovery
- **Acceptance Criteria**:
  - Services directory presents all 8 categories with clear CTAs into `/services/{slug}` and `/book?service={slug}`.
  - Vehicle catalogue filters by `category`, `min_seats`, `luggage_capacity`, `max_price`, `ac`/facilities, and optional `pickup_at`/`expected_end_at` availability check; updates URL query parameters and renders `Skeleton`, `Empty`, and `Error` states.

### `WEB-004` — Booking & Quote Request Wizard
- **Acceptance Criteria**: Captures customer contact (optional guest or pre-filled logged-in), service category, preferred vehicle, pickup, destination, ordered intermediate stops (`add`/`remove`/`reorder`), pickup & expected return timestamps, passenger/cargo specs, and notes. Submits with `Idempotency-Key` and handles `409 RESOURCE_CONFLICT` clearly.

### `WEB-005` — Customer Authentication & Ownership Portal
- **Acceptance Criteria**: Registration, login, logout, password reset, and guest booking claim flow. Protected `/dashboard/*` routes redirect unauthenticated users to `/login?redirect=...`. Customers see ONLY their own bookings, quotes, invoices, and active trip tracking.

### `WEB-006` — Active Trip Tracking
- **Acceptance Criteria**: When a booking is active (`en_route_to_pickup`..`at_destination`) and tracking is enabled by backend policy, `/dashboard/track/{booking_id}` renders OSM tile map, live vehicle marker, last GPS timestamp, freshness badge (`live`/`stale`/`offline`), trip status, and approved driver/vehicle info. Outside authorized windows, displays clear unavailable state.

### `WEB-007` — SEO, Accessibility & Performance
- **Acceptance Criteria**: Unique `<title>`, `<meta name="description">`, `<link rel="canonical">`, Open Graph tags, JSON-LD structured data, `/sitemap.xml`, `/robots.txt`, lazy-loaded WebP images with explicit dimensions, WCAG 2.1 AA contrast & keyboard navigation.

## 4. Assumptions & Dependencies
- Depends on Backend `/api/v1/public/catalog/*`, `/bookings`, `/quotations`, `/finance`, `/tracking`, and `/ws`.
- Guest vs mandatory account behavior follows configurable `BD-07` in [shared-contracts/open-decisions.md](../../shared-contracts/open-decisions.md).
