# VeloFleet Admin Dashboard (Flutter Windows Desktop)

Enterprise fleet, booking, dispatch, and operations desktop app built with Feature-based Clean Architecture, `flutter_bloc`, and `flutter_map`.

## Quick Start

1. Install packages:
   ```powershell
   flutter pub get
   ```
2. Run on Windows desktop:
   ```powershell
   flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000/api/v1
   ```
3. Build release Windows executable:
   ```powershell
   flutter build windows --release
   ```

## Verification Commands

- Analyze: `flutter analyze`
- Tests: `flutter test`
