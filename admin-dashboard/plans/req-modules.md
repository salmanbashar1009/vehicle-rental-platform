# Admin Dashboard Requirements: 12 Operational Modules

## 1. Operations & Dispatch Modules
- **`ADM-DASH-001` Dashboard Overview**:
  - Fleet status KPIs: `total`, `available`, `reserved`, `assigned`, `active`, `maintenance`, `out_of_service` vehicles; driver duty breakdown.
  - Booking/trip KPIs: pending enquiries, awaiting quote acceptance, confirmed, active trips, completed today; today's revenue & outstanding balances.
  - Today's dispatch timeline, recent activity feed, operational alerts (expiring docs, declined assignments, GPS loss, incidents), and mini live fleet map.
- **`ADM-BOOK-001` Booking Management**:
  - Paginated/filterable booking table (`status`, `service_category`, `date_range`, `search`); slide-over/full detail view.
  - Manual booking creation; review/approve/reject; itemized quotation builder (line items, deposit, validity date, terms); confirm, modify, reschedule, cancel.
  - Full booking timeline, internal staff notes, customer communication log, assignment history, and linked trip/expense records.
- **`ADM-DISP-001` Dispatch Management**:
  - Split-pane view: confirmed bookings needing dispatch vs eligible vehicles & drivers (`conflict`, `maintenance`, `expired_licence`, `capacity_match` indicators).
  - Atomic assign and reassign (with reason dialog); handles `409 RESOURCE_CONFLICT` cleanly by refreshing eligible list and highlighting conflict; Phase 5 adds smart ranking.
- **`ADM-MAP-001` Live Fleet Monitoring**:
  - Interactive `flutter_map` showing active vehicles, driver/booking/status popup on marker click, ordered stops & route polylines, freshness badges (`live`/`stale`/`offline`), loss alerts, and Phase 3 historical route playback.

## 2. Fleet, Drivers & Maintenance Modules
- **`ADM-FLEET-001` Fleet Management**:
  - Vehicle CRUD (`plate_number`, category, make/model/year, passenger/luggage/cargo capacity, fuel, facilities), S3 image gallery upload, odometer history, availability calendar (bookings + maintenance), and document expiry tracker (`30d`/`7d`/`0d` badges).
- **`ADM-DRV-001` Driver Management**:
  - Driver profiles, photo, contact & emergency contact, licence number/classes/expiry, employment & availability status, assignment history, performance ratings, and incident history.
- **`ADM-MAINT-001` Maintenance Management**:
  - Preventive maintenance schedules, service/repair/tyre/battery/oil records, service provider & cost tracking, document reminders, and automatic vehicle availability locking (`409` warning if conflicting booking exists).

## 3. Finance, CRM, Alerts, Reports & RBAC Modules
- **`ADM-FIN-001` Financial Management**:
  - Per-booking quoted/agreed/paid/refunded/outstanding summary; record deposits, partial/full payments, extra charges, discounts, refunds (approval + reason), payment method & reconciliation status; driver allowances & fuel/toll/parking/maintenance expenses; invoice/receipt preview & download.
- **`ADM-CRM-001` Customer Management**:
  - Individual & corporate customer directory, negotiated corporate rates/terms, booking history, outstanding balances, internal notes, communication log.
- **`ADM-NOTIF-001` Notifications Center**:
  - Real-time in-app inbox + urgent toast banners for new bookings, quotes, assignments/declines, trip milestones, payments, maintenance due, and driver incidents.
- **`ADM-RPT-001` Reports & Analytics**:
  - Period booking, cash flow vs recognized revenue, expense, vehicle utilization, driver performance, cancellation rate, service popularity, and customer retention views + CSV/PDF export.
- **`ADM-RBAC-001` Users & Roles**:
  - Staff user CRUD, role assignment across the 6 staff roles (`Owner`, `Booking Mgr`, `Fleet Mgr`, `Dispatcher`, `Accountant`, `Support`), activate/deactivate with audit reason.
