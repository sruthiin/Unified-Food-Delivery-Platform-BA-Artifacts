-- ====================================================================
-- PROJECT: UNIFIED FOOD DELIVERY PLATFORM
-- COMPLIANCE LAYER: DATABASE SCHEMA VALIDATION & RULE CONSTRAINTS
-- DESIGNED BY: ADVANCED PRODUCT BUSINESS ANALYST
-- ====================================================================

USE unified_food_delivery_db;

-- --------------------------------------------------------------------
-- BUSINESS CONSTRAINT 01: MULTI-MERCHANT CART INTERFERENCE GATING
-- Rule: A customer cannot place an order or have a cart containing 
-- active line items from multiple distinct restaurants simultaneously.
-- --------------------------------------------------------------------
CREATE TABLE customer_active_cart_line_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    restaurant_id VARCHAR(50) NOT NULL,
    item_id VARCHAR(50) NOT NULL,
    quantity INT DEFAULT 1,
    cart_state_status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AUDIT QUERY FOR SPRINT QA: Detect cart vulnerability bypass loops
SELECT 
    cart_id, 
    customer_id, 
    COUNT(DISTINCT restaurant_id) AS conflicting_merchant_count
FROM 
    customer_active_cart_line_items
WHERE 
    cart_state_status = 'ACTIVE'
GROUP BY 
    cart_id, customer_id
HAVING 
    conflicting_merchant_count > 1;

-- --------------------------------------------------------------------
-- BUSINESS CONSTRAINT 02: HIGH-FREQUENCY TELEMETRY RECONCILIATION
-- Rule: Captures real-time GPS coordinates of active delivery partners
-- during transit phases ('Picked Up', 'Arrived at Location').
-- --------------------------------------------------------------------
CREATE TABLE courier_active_tracking_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    delivery_partner_id VARCHAR(50) NOT NULL,
    associated_order_id VARCHAR(50) NOT NULL,
    current_spatial_latitude DECIMAL(10, 8) NOT NULL,
    current_spatial_longitude DECIMAL(11, 8) NOT NULL,
    active_routing_state VARCHAR(30) NOT NULL,
    device_telemetry_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AUDIT QUERY FOR DEVELOPMENT SPRINT: Trace latency drops over 120 seconds
SELECT 
    delivery_partner_id, 
    associated_order_id, 
    current_spatial_latitude, 
    current_spatial_longitude, 
    device_telemetry_timestamp
FROM 
    courier_active_tracking_logs
WHERE 
    active_routing_state IN ('Picked Up', 'Arrived at Location')
ORDER BY 
    device_telemetry_timestamp DESC 
LIMIT 25;
