# System Architecture Overview

## Stack Reconciliation (PDF v1.0 vs Mandatory Stack)

| Layer | PDF v1.0 Suggestion | Mandatory Platform Stack |
| --- | --- | --- |
| Customer Website | Next.js / React or Flutter Web | **Jaspr (Dart)** with component-style CSS & SSR/SEO |
| Admin Dashboard | Next.js / React or Flutter Web | **Flutter Windows Desktop** (Clean Arch + BLoC) |
| Driver Mobile App | Flutter (Android-first) | **Flutter Android & iOS** (Clean Arch + BLoC) |
| Backend API | NestJS (TypeScript) | **FastAPI (Python 3.12)** Modular Monolith |
| Database & Cache | PostgreSQL + Redis | **PostgreSQL 16** (`btree_gist`) + **Redis 7** |
| Maps & Tiles | Google Maps Platform | **`flutter_map`** + configurable OSM-compatible tiles |
| Storage & Push | S3-compatible + FCM | **S3-compatible (MinIO dev)** + **FCM** |

## High-Level Topology

```
+--------------------+   +--------------------+   +--------------------+
|  Customer Website  |   |  Admin Dashboard   |   |    Driver App      |
|  Jaspr (Dart/SSR)  |   |  Flutter Windows   |   |  Flutter iOS/Andr. |
+---------+----------+   +---------+----------+   +---------+----------+
          | HTTPS / WSS            | HTTPS / WSS            | HTTPS / WSS
          +------------------------+------------------------+
                                   |
                       +-----------v-----------+
                       |   Reverse Proxy /     |
                       |   TLS Termination     |
                       +-----------+-----------+
                                   |
                       +-----------v-----------+
                       |  FastAPI Modular      |
                       |  Monolith (/api/v1)   |
                       +-+---------+---------+-+
                         |         |         |
           +-------------+   +-----+-----+   +-------------+
           v                 v           v                 v
   +---------------+ +-------------+ +----------+ +----------------+
   | PostgreSQL 16 | |   Redis 7   | | S3 Store | | Async Workers  |
   | Core + PostGIS| | PubSub/Rate | | Docs/Img | | FCM/Email/Jobs |
   | /btree_gist   | | Live GeoTTL | | Receipts | | Expiry/Reports |
   +---------------+ +-------------+ +----------+ +----------------+
```

## Core Architectural Principles

1. **Modular Monolith**: Single deployable FastAPI service with strict module boundaries (`core`, `modules/*`, `integrations`, `workers`). Modules communicate through public service interfaces or domain events, never cross-module ORM table joins bypassing module ownership.
2. **Real-Time & GPS Separation**:
   - High-frequency driver GPS batches hit `/api/v1/tracking/locations/batch`.
   - Latest positions update Redis (`geo`/`hash` with TTL) and publish to Redis Pub/Sub -> WebSocket fan-out.
   - Sampled/filtered trajectory points persist to PostgreSQL `location_points` asynchronously with configurable retention.
3. **Database-Enforced Integrity**: Overlapping vehicle/driver allocations are rejected by PostgreSQL exclusion constraints, independent of application concurrency.
4. **Configurable Policy Engine**: Missing business rules (cancellation fees, deposits, pricing formulas, tracking windows) are parameterized in `system_policies` / `pricing_rules` rather than hardcoded.
