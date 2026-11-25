# Customer Website Implementation Tasks

Mark `[x]` only after implementation, `dart analyze`, `dart test`, and `<= 200`-line check pass.

## Phase 0 – Discovery & Architecture
- [x] `WEB-000` Create `customer-website/plans/` (`GEMINI.md`, `requirements.md`, `req-pages-flows.md`, `design.md`, `design-css-seo.md`, `tasks.md`, `tests.md`).

## Phase 1 – Core MVP
- [x] `WEB-101` Scaffold Jaspr project (`pubspec.yaml`, `tokens.css`, `primitives.css`, `AppConfig`, `App` router + 404 page, `SiteHeader`/`SiteFooter`). *Deps: BE-101*. *Verified: `build_runner`, `dart test`.*
- [x] `WEB-102` Build reusable UI component library (`ServiceCard`, `VehicleCard`, `StatusBadge`, `EmptyState`, `ErrorBanner`, `BookingStopsSection`). *Deps: WEB-101*. *Verified: `components_models_test.dart`.*
- [x] `WEB-103` Implement typed API client (`ApiClient`, `ApiError`, `generateUuidV4` `Idempotency-Key`) and DTOs matching `shared-contracts/openapi.json`. *Deps: BE-114*. *Verified: `components_models_test.dart`.*
- [x] `WEB-104` Implement SEO layer (`SeoMetadata`, Open Graph, JSON-LD builders, `/robots.txt`, `/sitemap.xml`). *Deps: WEB-101*. *Verified: `seo_ssr_test.dart`.*
- [x] `WEB-105` Implement Marketing & Legal SSR pages (`/`, `/about`, `/contact`, `/faq`, `/legal/terms`, `/legal/privacy`, `/legal/cancellation`). *Deps: WEB-102, WEB-104*. *Verified: `seo_ssr_test.dart`.*
- [x] `WEB-106` Implement Catalogue pages (`/services`, `/services/{slug}`, `/vehicles` with multi-facet filters, `/vehicles/{id}`). *Deps: WEB-103, WEB-104*. *Verified: `seo_ssr_test.dart`.*
- [x] `WEB-107` Implement Booking / Quote Request Wizard (`/book`) with dynamic fields for all 8 service categories, ordered stops, and `/booking/confirmation/{ref}`. *Verified: `wizard_and_portal_e2e_test.dart`.*
- [x] `WEB-108` Implement Customer Auth (`/register`, `/login`) and Portal MVP (`/dashboard`, `/dashboard/bookings`, `/dashboard/bookings/{id}` with timeline & cancel). *Verified: `wizard_and_portal_e2e_test.dart`.*

## Phase 2–5 – Subsequent Enhancements
- [x] `WEB-201` Show released driver/vehicle details & live trip milestone stepper on `/dashboard/bookings/{id}`. *Deps: BE-202, WEB-108*. *Verified: `tracking_portal_test.dart` + booking portal detail route.*
- [x] `WEB-301` Implement `/dashboard/track/{booking_id}` with OSM map widget, WebSocket live updates, freshness pill, and inactive-window fallback. *Deps: BE-302, WEB-201*. *Verified: `tracking_portal_test.dart`.*
- [x] `WEB-401` Implement `/dashboard/quotations/{id}` (Accept/Reject + expiry timer) & `/dashboard/payments/{booking_id}` (pay deposit/balance, invoice/receipt download). *Deps: BE-402, WEB-108*. *Verified: `finance_portal_test.dart`.*
- [x] `WEB-501` Implement post-service review form on completed bookings & corporate account portal views. *Deps: BE-502, BE-503*. *Verified: `phase5_reviews_test.dart`.*
