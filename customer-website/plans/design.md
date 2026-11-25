# Customer Website Design (Entry Point)

## 1. Architecture Overview
Component-based Jaspr application separating server-rendered SEO routes from hydrated interactive islands (`@client`).

### Supplementary Design Specifications
- [design-css-seo.md](design-css-seo.md) — Component-style CSS tokens/patterns, brand UI/UX system, SEO & JSON-LD rules
- [shared-contracts/design-system.md](../../shared-contracts/design-system.md) & [design-tokens.md](../../shared-contracts/design-tokens.md)

## 2. Directory & Module Structure
```
customer-website/lib/
├── main.dart                    # Server/client bootstrap
├── app.dart                     # Root Document, Theme links, Router
├── core/
│   ├── config/app_config.dart   # Env config (API_BASE_URL, WS_URL, TILE_URL, SITE_URL)
│   ├── http/
│   │   ├── api_client.dart      # Typed HTTP wrapper, correlation ID, refresh retry
│   │   └── api_error.dart       # Maps backend error envelope to typed UiFailure
│   ├── router/app_router.dart   # Typed routes + auth guard + HTTP 404 handler
│   ├── seo/seo_head.dart        # Title, meta, canonical, OG, JSON-LD, sitemap/robots
│   └── styles/                  # tokens.css, reset.css, primitives.css
├── components/                  # Pure reusable UI primitives + *.styles.dart
│   ├── buttons/                 # Primary, Secondary, Outline, Ghost, Destructive
│   ├── forms/                   # InputField, SelectField, DateTimeField, StopEditor
│   ├── display/                 # VehicleCard, ServiceCard, StatusBadge, TimelineStepper
│   ├── feedback/                # SkeletonBox, EmptyState, ErrorBanner, ConfirmModal
│   └── layout/                  # SiteHeader, MobileDrawer, SiteFooter, PageShell
└── features/
    ├── marketing/               # Home, About, Contact, FAQ, Legal
    ├── catalog/                 # Services, ServiceDetail, Vehicles, VehicleDetail
    ├── booking/                 # WizardController, 4-step Wizard, Confirmation
    ├── auth/                    # AuthController, Login, Register, ForgotPassword
    └── portal/                  # Dashboard, Bookings, BookingDetail, Quote, Pay, Track
```

## 3. State Management & Data Flow
- Hydrated features use lightweight typed `ChangeNotifier` controllers (`CatalogController`, `BookingWizardController`, `AuthController`, `TrackingController`) paired with Jaspr `ListenableBuilder` / `StatefulComponent`.
- Every async controller models explicit `AsyncState<T>`: `Loading`, `Data(T)`, `Empty`, `Failure(UiFailure)`.
- **Security**: Auth tokens stored via HTTP-only session cookie proxy or secure session storage; never echoed in SSR HTML props. All `/book` and quote-accept calls attach a fresh UUID `Idempotency-Key`.

## 4. UI State & Visual Consistency Rules
1. Every interactive screen defines Loading skeleton, Empty state with CTA, Error banner with retry, and Success confirmation.
2. Status badges (`requested`, `quoted`, `confirmed`, `in_progress`, `completed`, `cancelled`) consume exact semantic color tokens from `tokens.css`.
3. Active trip tracking map (`/dashboard/track/{booking_id}`) uses a clean JS-interop Leaflet/OSM component configured with `TILE_URL` + attribution, rendering vehicle marker, pickup/drop pins, freshness badge, and graceful fallback if GPS is `stale` or `offline`.
