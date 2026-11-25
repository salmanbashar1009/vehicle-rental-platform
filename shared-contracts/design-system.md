# Shared Product Design System

## Brand Identity: "VeloFleet" (Configurable White-Label Brand)

- **Visual Character**: Trustworthy, modern, spacious, eye-soothing, vibrant yet restrained. Crisp neutral surfaces paired with deep sapphire trust primary, energetic teal mobility accent, and warm amber highlights.
- **Anti-Patterns Forbidden**: Generic template boxes, heavy drop shadows, neon gradients, excessive glassmorphism, overcrowded tables, status colors differing across apps.

## Cross-Platform UX Adaptation

| Dimension | Customer Website (Jaspr) | Admin Dashboard (Flutter Win) | Driver App (Flutter Mobile) |
| --- | --- | --- | --- |
| Primary Goal | Discovery, trust, conversion | High-density control & dispatch | Safe, low-cognitive-load execution |
| Navigation | Top sticky header + CTA + footer | Collapsible left sidebar + shortcuts | Bottom 3-tab nav + primary action |
| Density | Spacious marketing & wizard cards | Data tables, split map/list panes | Large touch targets (>=48dp) |
| Map Usage | Active booking track view (read-only) | Multi-vehicle fleet map + filters | Current stop map + external nav |
| Safety Rule | Clear form feedback & accessibility | Confirm dialogs for destructive ops | Critical actions require stationary confirm |

## Canonical Reusable Component Catalog

All three apps must implement consistent equivalents of:
1. **Buttons**: Primary, Secondary, Outline, Ghost, Destructive (with loading spinner & disabled state).
2. **Inputs**: Text, Phone, Email, Password, Search, Date/Time Range Picker, Stop Autocomplete/List, Dropdown.
3. **Data Display**: Vehicle Card, KPI Stat Tile, Sortable/Filterable Data Table (Admin), Timeline Stepper, Status Badge.
4. **Feedback & Overlays**: Explicit Loading Skeleton, Empty State (icon + explanation + CTA), Error State (retry action), Confirmation Dialog, Slide-over Drawer, Toast/Banner.
5. **Map Markers & Freshness Badges**: Vehicle marker colored by operational status + `live` (green), `stale` (amber), `offline` (red/gray) indicator.

## Accessibility & Contrast Baseline

- Minimum WCAG 2.1 AA contrast (`4.5:1` body text, `3:1` large text & UI controls).
- Full keyboard navigation + visible focus rings on Jaspr and Flutter Desktop.
- Status badges always pair color with text label and/or icon (never color-only).
