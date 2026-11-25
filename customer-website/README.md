# VeloFleet Customer Website (Jaspr SSR + Client Hydration)

SEO-friendly public transportation website and customer self-service portal built with Jaspr (`0.23.5`) and component-style CSS.

## Quick Start

1. Install dependencies and build Jaspr options:
   ```powershell
   dart pub get
   dart run build_runner build
   ```
2. Run development SSR server (port `8080`):
   ```powershell
   jaspr serve
   ```
3. Production build:
   ```powershell
   jaspr build
   ```

## Verification Commands

- Analyze: `dart analyze`
- Tests: `dart test`
