# Database Core Validation Matrix & Business Gating

This directory contains structural validation rules mapping the functional constraints for the **Unified Food Delivery Platform database layers (MySQL)**.

## Core Rules Audited:
1. **Multi-Merchant Cart Gating (FR-03 Compliance):** * Prevents operational issues where data splits over different restaurants in a single checkout rail.
   * Checks for structural cart discrepancies by monitoring `restaurant_id` uniqueness.
2. **Telemetry Synchronization Interval Latency Check:**
   * Gathers high-frequency location data from driver app instances to manage real-time customer geofencing maps.
