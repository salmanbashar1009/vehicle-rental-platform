# Open Business Decisions & Documented Assumptions

Per engineering rules, unresolved business policies are **not invented**; they are listed here for stakeholder confirmation and implemented via configurable backend policies (`system_policies` / `service_categories`).

## Unresolved Business Decisions (Stakeholder Input Needed)

| ID | Topic | Options / Impact | Safe Configurable Default for MVP |
| --- | --- | --- | --- |
| BD-01 | Primary currency, timezone & tax/VAT | Single vs multi-currency; VAT rate | `USD` + `UTC` configurable via `system_policies`; tax line optional |
| BD-02 | Instant confirm vs admin review | Which services auto-confirm vs require quote | All requests enter `requested` for admin quote/confirm by default; flag per `service_category` |
| BD-03 | Deposit & payment terms | % deposit vs fixed vs pay-on-completion | Configurable `deposit_percent` per quote; manual payment recording in Phase 1, online gateway in Phase 4 |
| BD-04 | Cancellation & no-show fees | Free cutoff window, % penalty tiers | Configurable `cancellation_policies` table; zero auto-charge until approved |
| BD-05 | Pricing formula parameters | Per-km, per-hour, waiting, overnight, fuel | Itemized admin quotations in Phase 1 + configurable `pricing_rules` engine |
| BD-06 | Fleet ownership model | Company-owned only vs partner vehicles | `ownership_type` enum (`company_owned` default, extensible to `partner`) |
| BD-07 | Guest booking vs mandatory login | Guest enquiry vs account required | Guest enquiry allowed (returns ref + claim token); account required for portal/tracking |
| BD-08 | Customer live-tracking window | When customer sees map & driver contact | Enabled only when `trip.status` in (`en_route_to_pickup`..`at_destination`) and booking flag enabled |
| BD-09 | GPS history retention period | 30 / 90 / 180 days compliance limit | Configurable `gps_retention_days` (default 90 days) purged by scheduled worker |
| BD-10 | Mapping tile & SMS/WhatsApp providers | Commercial tile provider, Twilio/Meta/SMTP | Tile URL & key from env config; email/in-app/FCM first, SMS/WhatsApp pluggable adapters |

## Initial Validated Assumptions

1. Core business is chauffeur-driven rentals (both vehicle and driver assigned for fulfilled jobs).
2. Phase 1 targets a single operating company (`tenant_id` nullable/extensible for future multi-branch).
3. Manual dispatch & admin override remain available even after automated recommendations arrive in Phase 5.
4. Driver phone/contact masking can be layered via proxy adapter without breaking client contracts.
