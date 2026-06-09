-- ====================================================================
-- PROJECT: UNIFIED FOOD DELIVERY PLATFORM
-- ARTIFACT: CORE DATABASE VERIFICATION & AUDIT QUERIES
-- ====================================================================

-- VALIDATION RUN 01: MULTI-MERCHANT CART GATING EXCLUSION
SELECT cart_id, customer_id, COUNT(DISTINCT restaurant_id) AS conflicting_merchant_count
FROM customer_active_cart_line_items
WHERE cart_state_status = 'ACTIVE'
GROUP BY cart_id, customer_id
HAVING conflicting_merchant_count > 1;

-- VALIDATION RUN 02: TELEMETRY POLLING RECONCILIATION LATENCY TRACE
SELECT delivery_partner_id, associated_order_id, current_spatial_latitude, device_telemetry_timestamp
FROM courier_active_tracking_logs
WHERE active_routing_state IN ('Picked Up', 'Arrived at Location')
ORDER BY device_telemetry_timestamp DESC LIMIT 25;
