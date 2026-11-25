# OpenAPI Conventions & Payload Standards

## Request / Response Rules

- **Content Type**: `application/json; charset=utf-8` (except `multipart/form-data` for validated file uploads or presigned S3 upload flow).
- **Field Naming**: `snake_case` across all JSON payloads, query params, and OpenAPI schemas.
- **Correlation ID**: Every response includes `X-Correlation-ID`. Clients may supply `X-Correlation-ID` (UUID); backend generates one if absent.
- **Date & Time**: ISO-8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`), e.g., `2026-11-25T09:30:00Z`. Display timezone is applied on clients using configured business/user timezone.
- **Money Representation**:
  ```json
  { "amount_minor": 15000, "currency": "USD" }
  ```
  All monetary math uses `Decimal` or integer minor units (`amount_minor`); never IEEE-754 floats.

## Standard Pagination Envelope

List endpoints return:
```json
{
  "items": [],
  "page": 1,
  "page_size": 20,
  "total_items": 0,
  "total_pages": 0
}
```
Query parameters: `?page=1&page_size=20&sort_by=created_at&sort_dir=desc` (server enforces allowlisted `sort_by` fields and `page_size <= 100`).

## Standard Error Envelope

All non-2xx responses (400, 401, 403, 404, 409, 422, 429, 500) conform to:
```json
{
  "error": {
    "code": "RESOURCE_CONFLICT",
    "message": "Selected vehicle is unavailable for the requested window.",
    "details": [
      { "field": "vehicle_id", "issue": "overlaps_existing_reservation" }
    ],
    "correlation_id": "019363f2-8c1a-7b11-9c22-4a8e2b910001"
  }
}
```
Safe errors never expose stack traces, SQL text, internal paths, or PII.

## Idempotency Rules

- Mutating endpoints for booking submission (`POST /api/v1/bookings`), quotation acceptance (`POST /api/v1/quotations/{id}/accept`), payment creation (`POST /api/v1/finance/payments`), and GPS batch upload (`POST /api/v1/tracking/locations/batch`) accept/require `Idempotency-Key` header (UUID).
- Backend stores `(actor_scope, idempotency_key, request_hash, response_snapshot)` in PostgreSQL/Redis (24h+ TTL for bookings/payments) and returns `409 Conflict` if the same key is reused with a different payload hash.
