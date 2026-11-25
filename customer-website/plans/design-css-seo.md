# Customer Website Component-Style CSS & SEO Design

## 1. Component-Style CSS Pattern
- **Token Layer (`core/styles/tokens.css`)**: Exact CSS custom properties matching [shared-contracts/design-tokens.md](../../shared-contracts/design-tokens.md) (`--color-primary-700: #0F3D7A`, `--color-primary-500: #1D63DC`, `--color-secondary-600: #0D9488`, `--color-accent-500: #F59E0B`, `--color-bg-canvas: #F8FAFC`, spacing `--space-1..16`, radii, shadows, `Plus Jakarta Sans` / `Inter` / `JetBrains Mono`).
- **Primitive Layer (`core/styles/primitives.css`)**: Reusable `.vf-container`, `.vf-grid-*`, `.vf-btn`, `.vf-btn--primary`, `.vf-card`, `.vf-badge`, `.vf-badge--success|warning|error|info`, `.vf-input` so components never repeat border, padding, or transition declarations.
- **Component Styles (`*.styles.dart`)**: Each component defines its own Jaspr `@css` rules scoped by block prefix (e.g., `.vf-hero__*`, `.vf-wizard__*`, `.vf-navbar__*`) and keeps style files <= 150 lines.

## 2. UI/UX Design Direction
- **Hero Section**: Deep sapphire trust gradient (`#0F3D7A` -> `#144E9A` subtle two-stop) paired with high-contrast white headline, embedded quick-quote search bar (Service + Pickup Date + "Check Fleet & Quote"), and real chauffeur/vehicle photography.
- **Eye-Soothing Hierarchy**: Generous section whitespace (`--space-12` / `--space-16`), `#FFFFFF` surface cards with `1px solid #E2E8F0` hairlines, crisp dark slate `#0F172A` headings, `#475569` body copy.
- **Conversion Flow**: Every vehicle card and service detail links directly into `/book?service=...&vehicle_id=...` pre-populating the wizard to minimize friction.

## 3. SEO & Crawlability Specification
| Element | Implementation |
| --- | --- |
| **Page Titles & Meta** | Unique `<title>{Page} | VeloFleet Chauffeur & Fleet Rentals</title>` + 140–160 char `<meta name="description">` |
| **Canonical & Open Graph** | `<link rel="canonical" href="{site_url}{path}">`, `og:title`, `og:description`, `og:type`, `og:url`, `og:image`, `twitter:card=summary_large_image` |
| **Structured Data (`JSON-LD`)** | `AutoRental`/`LocalBusiness` on `/`, `Service` on `/services/{slug}`, `Product` on `/vehicles/{id}`, `FAQPage` on `/faq` |
| **`/robots.txt`** | `Allow: /`, `Disallow: /dashboard`, `Disallow: /login`, `Disallow: /register`, `Disallow: /booking/confirmation`, `Sitemap: {site_url}/sitemap.xml` |
| **`/sitemap.xml`** | Dynamically built from static routes + active `/services/{slug}` + public `/vehicles/{id}` |
| **Core Web Vitals** | Explicit `width`/`height` on `<img>`, `loading="lazy"` below fold, WebP photography, SSR zero-flicker typography |
