-- =====================================================
-- Unified Food Delivery Platform
-- Database Schema & Validation Rules (MySQL)
-- Last Updated: June 2026
-- =====================================================

USE unified_food_delivery_db;

-- =====================================================
-- CONSTRAINT 1: Multi-Merchant Cart Validation
-- Business Rule (CART-001): Customer cannot have 
-- items from multiple restaurants in a single cart
-- =====================================================

CREATE TABLE customer_active_cart_line_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    restaurant_id VARCHAR(50) NOT NULL,
    item_id VARCHAR(50) NOT NULL,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    cart_state_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cart (cart_id),
    INDEX idx_customer (customer_id),
    INDEX idx_restaurant (restaurant_id)
);

-- Constraint: One restaurant per active cart per customer
-- Implementation: Application must validate before INSERT

-- AUDIT QUERY 1: Detect carts with multiple restaurants
-- Expected Result: Empty set (0 rows) = validation working
SELECT 
    cart_id, 
    customer_id, 
    COUNT(DISTINCT restaurant_id) AS restaurant_count,
    GROUP_CONCAT(DISTINCT restaurant_id) AS restaurant_ids,
    'VIOLATION' AS status
FROM 
    customer_active_cart_line_items
WHERE 
    cart_state_status = 'ACTIVE'
GROUP BY 
    cart_id, customer_id
HAVING 
    COUNT(DISTINCT restaurant_id) > 1;

-- =====================================================
-- CONSTRAINT 2: Real-Time Delivery Partner Tracking
-- Business Rule (TRACKING-001): Capture GPS coordinates
-- during specific order states only (Picked Up, Arrived)
-- =====================================================

CREATE TABLE courier_active_tracking_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    delivery_partner_id VARCHAR(50) NOT NULL,
    associated_order_id VARCHAR(50) NOT NULL,
    current_spatial_latitude DECIMAL(10, 8) NOT NULL,
    current_spatial_longitude DECIMAL(11, 8) NOT NULL,
    active_routing_state VARCHAR(30) NOT NULL,
    device_telemetry_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Validate coordinate ranges
    CHECK (current_spatial_latitude BETWEEN -90 AND 90),
    CHECK (current_spatial_longitude BETWEEN -180 AND 180),
    
    -- Only allow tracking during specific states
    CHECK (active_routing_state IN ('Picked Up', 'Arrived at Location')),
    
    -- Indexes for common queries
    INDEX idx_delivery_partner (delivery_partner_id),
    INDEX idx_order (associated_order_id),
    INDEX idx_timestamp (device_telemetry_timestamp),
    INDEX idx_state (active_routing_state)
);

-- AUDIT QUERY 2: Get latest location for all active deliveries
-- Used by: Customer tracking dashboard
SELECT 
    delivery_partner_id, 
    associated_order_id, 
    current_spatial_latitude, 
    current_spatial_longitude, 
    active_routing_state,
    device_telemetry_timestamp
FROM 
    courier_active_tracking_logs
WHERE 
    active_routing_state IN ('Picked Up', 'Arrived at Location')
ORDER BY 
    delivery_partner_id, 
    device_telemetry_timestamp DESC
LIMIT 50;

-- =====================================================
-- CONSTRAINT 3: Order State Progression Validation
-- Business Rule (ORDER-001): Orders follow defined
-- state progression, no skipping or backward movement
-- =====================================================

CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    restaurant_id VARCHAR(50) NOT NULL,
    current_order_state VARCHAR(30) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Valid states only
    CHECK (current_order_state IN (
        'Order Placed',
        'Confirmed',
        'Accepted by Restaurant',
        'Preparation',
        'Ready for Pickup',
        'Picked Up',
        'Arrived at Location',
        'Delivered',
        'Cancelled'
    )),
    
    -- Indexes for lookups
    INDEX idx_customer (customer_id),
    INDEX idx_restaurant (restaurant_id),
    INDEX idx_state (current_order_state),
    INDEX idx_created (created_at)
);

-- AUDIT QUERY 3: Detect any orders in invalid states
-- Expected Result: Empty set (0 rows)
SELECT 
    order_id, 
    current_order_state,
    'INVALID_STATE' AS issue
FROM 
    orders
WHERE 
    current_order_state NOT IN (
        'Order Placed', 'Confirmed', 'Accepted by Restaurant',
        'Preparation', 'Ready for Pickup', 'Picked Up',
        'Arrived at Location', 'Delivered', 'Cancelled'
    );

-- =====================================================
-- CONSTRAINT 4: Payment Status Reconciliation
-- Business Rule (PAYMENT-001): No fulfillment without
-- successful payment. Orders cannot progress until
-- payment_status = 'SUCCESS'
-- =====================================================

CREATE TABLE order_payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL UNIQUE,
    payment_status VARCHAR(20) NOT NULL,
    payment_amount DECIMAL(10, 2) NOT NULL CHECK (payment_amount > 0),
    payment_method VARCHAR(30),
    transaction_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Valid payment statuses only
    CHECK (payment_status IN ('PENDING', 'SUCCESS', 'FAILED', 'RETRY_REQUIRED')),
    
    -- Foreign key to orders
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    
    -- Indexes for queries
    INDEX idx_order (order_id),
    INDEX idx_status (payment_status),
    INDEX idx_transaction (transaction_id)
);

-- AUDIT QUERY 4: Critical - Orders in fulfillment without successful payment
-- Expected Result: Empty set (0 rows) - If ANY rows appear, data integrity is broken
SELECT 
    o.order_id,
    o.current_order_state,
    COALESCE(p.payment_status, 'NO_PAYMENT_RECORD') AS payment_status,
    'CRITICAL_VIOLATION' AS severity
FROM 
    orders o
LEFT JOIN 
    order_payments p ON o.order_id = p.order_id
WHERE 
    -- These states require successful payment
    o.current_order_state IN (
        'Preparation', 
        'Ready for Pickup', 
        'Picked Up', 
        'Arrived at Location', 
        'Delivered'
    )
    -- But payment is missing or not successful
    AND (p.payment_status != 'SUCCESS' OR p.payment_status IS NULL);

-- =====================================================
-- COMPREHENSIVE VALIDATION REPORT
-- Run this query after data imports/migrations to verify
-- all constraints are working correctly
-- =====================================================

SELECT 
    'Cart Validation (Multi-Merchant)' AS constraint_name,
    COUNT(*) AS violation_count,
    'HIGH' AS severity
FROM (
    SELECT cart_id FROM customer_active_cart_line_items
    WHERE cart_state_status = 'ACTIVE'
    GROUP BY cart_id
    HAVING COUNT(DISTINCT restaurant_id) > 1
) AS cart_violations

UNION ALL

SELECT 
    'Payment Reconciliation' AS constraint_name,
    COUNT(*) AS violation_count,
    'CRITICAL' AS severity
FROM (
    SELECT o.order_id
    FROM orders o
    LEFT JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.current_order_state IN (
        'Preparation', 'Ready for Pickup', 'Picked Up', 
        'Arrived at Location', 'Delivered'
    )
    AND (p.payment_status != 'SUCCESS' OR p.payment_status IS NULL)
) AS payment_violations;

-- =====================================================
-- HELPER QUERIES FOR OPERATIONS
-- =====================================================

-- Get orders by state for operations dashboard
SELECT 
    current_order_state,
    COUNT(*) AS order_count,
    MAX(created_at) AS latest_order
FROM 
    orders
WHERE 
    created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY 
    current_order_state
ORDER BY 
    order_count DESC;

-- Get pending payments that need attention
SELECT 
    payment_id,
    order_id,
    payment_amount,
    payment_status,
    TIMESTAMPDIFF(MINUTE, created_at, NOW()) AS minutes_since_attempt
FROM 
    order_payments
WHERE 
    payment_status IN ('PENDING', 'RETRY_REQUIRED')
    AND created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)
ORDER BY 
    created_at ASC;
