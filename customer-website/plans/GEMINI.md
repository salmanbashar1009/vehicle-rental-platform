# Customer Website Engineering Instructions (`GEMINI.md`)

## 1. Project Overview & Stack
Public-facing website and authenticated customer self-service portal for the VeloFleet chauffeur-driven transportation platform.
- **Framework**: Jaspr (`0.23.4+`) — Dart server-rendered (SSR) + client hydration (`@client` islands)
- **Language**: Dart `3.13+` with strict analysis options (`strict-casts`, `strict-inference`, `strict-raw-types`)
- **Styling**: Component-style CSS pattern (`@css` rules / colocated style files + CSS custom property tokens)
- **Mapping (Active Trip Tracking)**: OpenStreetMap-compatible tile map widget via configurable tile URL + attribution (NEVER Google Maps SDK)

## 2. Architecture & Component-Style CSS Rules
```
customer-website/lib/
├── main.dart                  # Server/client entry point
├── app.dart                   # Document wrapper, head SEO slot, Router
├── core/
│   ├── config/                # API base URL, WS URL, tile URL, site origin
│   ├── http/                  # Typed API client, correlation ID, Idempotency-Key
│   ├── router/                # 22-route registry + auth redirect guard + 404
│   ├── seo/                   # SeoHead, OpenGraph, JSON-LD, sitemap/robots handlers
│   └── styles/                # tokens.css, reset.css, primitives.css (shared only)
├── components/                # Reusable UI primitives + colocated *.styles.dart
└── features/
    ├── marketing/             # Home, About, Contact, FAQ, Legal pages
    ├── catalog/               # Services, ServiceDetails, Vehicles, VehicleDetails
    ├── booking/               # Multi-step wizard + Confirmation
    ├── auth/                  # Register, Login, Password Recovery
    └── portal/                # Dashboard, History, Details, Quote, Payment, Tracking
```

**Mandatory CSS Rules**:
1. Shared design tokens (`--color-*`, `--space-*`, `--font-*`, `--radius-*`, `--shadow-*`) live ONLY in `core/styles/tokens.css` matching [shared-contracts/design-tokens.md](../../shared-contracts/design-tokens.md).
2. Extract shared layout/button/badge/card patterns into `core/styles/primitives.css`; **NEVER duplicate the same CSS declarations across components**.
3. Every component owns its scoped styles (`<component>.styles.dart` using `.vf-<block>__<elem>` naming); **NEVER create a giant global stylesheet**.
4. Avoid broad global element selectors outside `reset.css`.

## 3. Non-Negotiable Engineering & Security Constraints
1. **200-Line Hard Limit**: Every `.dart`, `.css`, `.html`, and `.md` file MUST be <= 200 lines.
2. **Backend Single Source of Truth**: Never calculate authoritative prices, discounts, or availability on the client; display indicative values only from `/api/v1/public/catalog`.
3. **No Secrets in Client**: Never embed API secrets, signing keys, or private storage credentials in hydrated Dart/JS.
4. **SEO & Accessibility**: Semantic HTML5 landmarks (`<header>`, `<nav>`, `<main>`, `<article>`, `<footer>`), unique `<title>` + meta description + canonical URL + OG tags on every public page, accessible contrast (`>= 4.5:1`), keyboard focus rings.
5. **No Shortcuts**: Always implement explicit `Loading`, `Empty`, `Error`, and `409 Conflict` states; never mark tasks `[x]` before tests pass.

## 4. Development & Verification Commands
- Install deps: `dart pub get`
- Analyze & format: `dart analyze && dart format --output=none --set-exit-if-changed .`
- Run tests: `dart test`
- Serve locally (SSR + hot reload): `jaspr serve`
- Build production bundle: `jaspr build`
