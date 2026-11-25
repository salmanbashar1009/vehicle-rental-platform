# Customer Website: 22-Page Inventory & User Flows

## 1. Complete Route Inventory
| Group | Route | Page & Key Elements | Auth | Render |
| --- | --- | --- | --- | --- |
| Marketing | `/` | Homepage: hero + quick booking search bar, 8 service cards, featured fleet, promotions, testimonials, FAQ teaser, contact CTA | Public | SSR |
| | `/about` | About Us: brand story, safety/chauffeur standards, fleet quality metrics | Public | SSR |
| | `/services` | Services Directory: 8 transport categories with typical use cases | Public | SSR |
| | `/services/{slug}` | Service Details: itinerary/workflow overview, inclusions, direct quote CTA | Public | SSR |
| | `/vehicles` | Vehicle Catalogue: multi-facet filters, availability indicator, indicative price | Public | SSR+Client |
| | `/vehicles/{id}` | Vehicle Details: image gallery, passenger/luggage/cargo specs, facilities, book CTA | Public | SSR+Client |
| Booking | `/book` | Booking/Quote Request Wizard: 4-step guided flow + dynamic service fields | Public/Auth | Client |
| | `/booking/confirmation/{ref}` | Booking Confirmation: reference code, summary, guest-to-account claim CTA | Public/Auth | SSR+Client |
| Auth | `/register` | Customer Registration: full name, email, phone, password validation | Public | Client |
| | `/login` | Customer Login + Forgot Password modal/flow | Public | Client |
| Portal | `/dashboard` | Customer Dashboard: active trip card, upcoming bookings, pending quotes | Customer | Auth |
| | `/dashboard/bookings` | Booking History: tabs (`Current`, `Upcoming`, `Completed`, `Cancelled`) | Customer | Auth |
| | `/dashboard/bookings/{id}` | Booking Details: stops, timeline, driver/vehicle when released, reschedule/cancel, feedback CTA | Customer | Auth |
| | `/dashboard/quotations/{id}` | Quotation Details: itemized charges, tax, deposit, validity timer, Accept/Reject | Customer | Auth |
| | `/dashboard/payments/{booking_id}` | Payment & Invoice: paid/due breakdown, pay deposit/balance, download invoice/receipt | Customer | Auth |
| | `/dashboard/track/{booking_id}` | Active Trip Tracking: OSM map, live marker, freshness pill, ETA if reliable, support CTA | Customer | Auth+WS |
| Support | `/contact` | Contact Us: support inquiry form, office address, phone/email hours | Public | SSR+Client |
| | `/faq` | FAQ: searchable/expandable Q&A accordion | Public | SSR |
| Legal | `/legal/terms` | Terms and Conditions | Public | SSR |
| | `/legal/privacy` | Privacy Policy (data handling + GPS tracking disclosure) | Public | SSR |
| | `/legal/cancellation` | Cancellation Policy | Public | SSR |
| Fallback | `/*` | Not Found Page (HTTP 404, helpful links back to Home/Vehicles) | Public | SSR |

## 2. Dynamic Booking Wizard Fields by Service Category
- **Tour & Travel**: multi-destination stops, overnight stay toggle, itinerary notes.
- **Event Transportation**: venue name, event start/end, return trip toggle.
- **House Shifting / Cargo**: cargo item/volume estimate, pickup/drop floor & elevator flags, loading/unloading assistance toggle.
- **Airport Transfer**: airline + flight number, terminal, arrival vs departure toggle, luggage count.
- **Corporate / Periodic Rental**: company/billing reference, rental period (`daily`/`weekly`/`monthly`), expected mileage.

## 3. Edge Cases
- Preferred vehicle becomes unavailable before submit -> backend returns `409`; wizard highlights schedule step with alternative suggestion CTA.
- Quote expires while viewing -> Accept button disabled with clear "Quotation Expired — Request Updated Quote" action.
- WebSocket disconnects during live tracking -> falls back to 15s REST poll + shows `Reconnecting...` banner.
