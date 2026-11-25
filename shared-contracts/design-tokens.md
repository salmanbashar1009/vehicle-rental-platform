# Canonical Design Tokens

All three frontends (`customer-website` CSS variables, `admin-dashboard` `ThemeExtension`, `driver-app` `ThemeExtension`) consume these exact token definitions.

## Color Palette

| Token | Hex | Usage |
| --- | --- | --- |
| `--color-primary-700` | `#0F3D7A` | Primary brand, headers, trust anchors |
| `--color-primary-500` | `#1D63DC` | Primary CTAs, active nav, focus rings |
| `--color-primary-100` | `#E8F0FE` | Selected rows, soft primary badges |
| `--color-secondary-600` | `#0D9488` | Mobility/dispatch accents, secondary CTA |
| `--color-accent-500` | `#F59E0B` | Highlights, pending attention, ratings |
| `--color-bg-canvas` | `#F8FAFC` | App background canvas (light) |
| `--color-surface-card` | `#FFFFFF` | Cards, tables, dialogs (light) |
| `--color-surface-muted` | `#F1F5F9` | Table headers, input fills, sidebars |
| `--color-border-subtle` | `#E2E8F0` | Hairlines, dividers, card borders |
| `--color-text-primary` | `#0F172A` | Headings, primary copy |
| `--color-text-secondary` | `#475569` | Captions, metadata, labels |
| `--color-text-muted` | `#94A3B8` | Placeholders, disabled text |
| `--color-dark-canvas` | `#0B1220` | Driver app optional dark mode canvas |
| `--color-dark-surface` | `#162033` | Driver app optional dark mode cards |

## Semantic Status Colors

| Status | Text/Icon | Background | Meaning |
| --- | --- | --- | --- |
| `success` / `completed` / `live` | `#047857` | `#D1FAE5` | Confirmed, paid, completed, live GPS |
| `warning` / `pending` / `stale` | `#B45309` | `#FEF3C7` | Quoted, pending ack, maintenance due |
| `error` / `cancelled` / `offline` | `#B91C1C` | `#FEE2E2` | Rejected, incident, overdue, GPS lost |
| `info` / `active` / `en_route` | `#0369A1` | `#E0F2FE` | Assigned, en route, journey started |

## Typography, Spacing, Radii & Shadows

- **Font Families**: `Plus Jakarta Sans` (display/headings), `Inter` (UI/body), `JetBrains Mono` (booking refs, plates, timestamps).
- **Type Scale (px)**: `12` (caption), `14` (body-sm), `16` (body), `18` (title-sm), `20` (title-md), `24` (h3), `32` (h2), `44` (h1/hero).
- **Spacing (4px grid)**: `4, 8, 12, 16, 20, 24, 32, 40, 48, 64`.
- **Border Radii**: `sm: 6px`, `md: 10px`, `lg: 14px`, `xl: 20px`, `pill: 9999px`.
- **Elevation Shadows**:
  - `shadow-sm`: `0 1px 2px rgba(15, 23, 42, 0.06)`
  - `shadow-md`: `0 6px 16px rgba(15, 23, 42, 0.08)`
  - `shadow-lg`: `0 14px 32px rgba(15, 23, 42, 0.12)`
- **Responsive Breakpoints (Web/Desktop)**: `sm: 640px`, `md: 768px`, `lg: 1024px`, `xl: 1280px`, `2xl: 1536px`.
