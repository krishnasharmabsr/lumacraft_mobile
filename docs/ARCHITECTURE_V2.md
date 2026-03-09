# Architecture V2

## Overview

LumaCraft uses a strictly layered Clean Architecture, isolating UI, domain logic, and external services.

## Directory Structure

- `lib/core/` (DI, routing, theme, environment)
- `lib/features/` (import, preview, export, home UI)
- `lib/services/`
  - `engine/` (FFmpeg abstractions, ML models)
  - `monetization/` (AdMob, RevenueCat/Play Billing)

## Key Constraints

- **Zero Paid Cloud Processing:** All heavy lifting must be done on-device via FFmpeg or local ML.
- **Memory Efficiency:** Avoid loading full videos into memory; use streams/proxies.
- **Handoff Safety:** Clear abstraction boundaries between layers to allow safe AI agent handoffs.
