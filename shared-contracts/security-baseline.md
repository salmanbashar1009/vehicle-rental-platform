# Cybersecurity Baseline (Non-Negotiable)

Reference: OWASP ASVS Level 2 & OWASP API Security Top 10.

## 1. Authentication & Session Security

- **Password Hashing**: Argon2id (`argon2-cffi`, memory >= 64 MiB, iterations >= 3, parallelism >= 1).
- **JWT Tokens**:
  - Access Token: RS256/EdDSA or strong HS256 (32+ byte secret), TTL `15 minutes`.
  - Refresh Token: Opaque cryptographically random token (`secrets.token_urlsafe(48)`), stored hashed (SHA-256) in `auth_sessions` table, rotated on every use with reuse-detection revoking the entire token family.
- **Brute-Force Protection**: Redis sliding-window rate limits per IP + email/phone; progressive lockout after 5 failed attempts.
- **MFA**: Optional TOTP MFA (`pyotp`) for `owner` and `accountant` roles (design-ready in Phase 1, enforced per policy).

## 2. Authorization & Anti-IDOR

- **RBAC**: Backend dependency verifies JWT + role permissions (`owner`, `booking_manager`, `fleet_manager`, `dispatcher`, `accountant`, `customer_support`, `driver`, `customer`).
- **Object-Level Authorization (BOLA/IDOR)**:
  - Customers can ONLY read/act on bookings, quotations, invoices, and tracking where `booking.customer_id == current_customer.id`.
  - Drivers can ONLY read/act on assignments and trips where `assignment.driver_id == current_driver.id` and `assignment.status` is authorized.

## 3. API, Upload & Data Protection

- **Input/Output**: Strict Pydantic schemas (`extra="forbid"` on write DTOs); SQLAlchemy parameterized queries only (zero string-formatted SQL); never return ORM models directly.
- **Headers & CORS**: Explicit origin allowlist, `HSTS`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, CSP on Jaspr web responses.
- **File Uploads**: Allowlist MIME types via magic bytes (`image/jpeg`, `image/png`, `image/webp`, `application/pdf`), max size 10 MB, random UUID object keys, private S3 bucket with short-lived presigned URLs (5 min) for sensitive documents.
- **Secrets**: `.env.example` placeholders only; never commit keys; redact `Authorization`, `password`, `token`, `refresh_token` from structured logs and Sentry payloads.

## 4. GPS Privacy & Verification

- Collection strictly gated to `en_route_to_pickup` -> `service_completed`.
- Customer tracking only exposes live vehicle marker + anonymized/approved driver display name & vehicle plate when admin/policy enables tracking.
- Pre-release security gates: `bandit`, `pip-audit`, `gitleaks`/secret scan, and automated IDOR/RBAC/SQLi/rate-limit pytest suite.
