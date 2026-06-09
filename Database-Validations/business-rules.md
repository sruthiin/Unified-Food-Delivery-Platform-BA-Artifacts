# Database Validation Rules & Business Constraints

This document outlines the core business rules enforced at the database layer for the Unified Food Delivery Platform.

## Rule 1: Multi-Merchant Cart Prevention

**Requirement ID:** CART-001  
**Priority:** High  
**Category:** Business Logic Constraint

### Business Context
Customers should not be able to combine items from multiple restaurants in a single order. This prevents:
- Operational complexity in order routing
- Delivery inefficiencies
- Customer confusion about order consolidation
- Cart state management issues

### Functional Rule
A customer's active cart can only contain items from ONE restaurant at a time.

When a customer attempts to add items from a different restaurant:
- **Option A:** Replace the existing cart (recommended approach)
- **Option B:** Display an error prompting cart clearance

### Database Implementation
- **Table:** `customer_active_cart_line_items`
- **Key Constraint:** Only one unique `restaurant_id` per `cart_id`
- **Validation:** Prevent INSERT/UPDATE if constraint would be violated

### Acceptance Criteria
```
Scenario 1: Adding items from same restaurant
  Given: Customer has items from Restaurant A in active cart
  When: Customer adds item from Restaurant A
  Then: Item is added successfully to cart
  
Scenario 2: Adding items from different restaurant
  Given: Customer has items from Restaurant A in active cart
  When: Customer attempts to add item from Restaurant B
  Then: System either:
    - Clears Restaurant A items and adds Restaurant B item, OR
    - Shows error message: "Please clear your cart before adding items from another restaurant"
  And: Only Restaurant B items remain in cart after action
```

---

## Rule 2: Real-Time Delivery Partner Location Tracking

**Requirement ID:** TRACKING-001  
**Priority:** High  
**Category:** Real-Time Data Capture

### Business Context
Enable customers to track delivery partners in real-time once an order has been picked up from the restaurant. This provides:
- Transparency and trust for customers
- Accurate ETA calculations
- Real-time issue detection
- Quality assurance data for delivery operations

### Functional Rule
Capture GPS coordinates (latitude/longitude) for active delivery partners during specific order states only.

**Valid States for Location Capture:**
- `Picked Up` - Delivery partner has collected order from restaurant
- `Arrived at Location` - Delivery partner has arrived at customer location

### Database Implementation
- **Table:** `courier_active_tracking_logs`
- **Key Columns:** 
  - `delivery_partner_id` - Identifies the delivery partner
  - `associated_order_id` - Links to specific order
  - `active_routing_state` - Must be one of valid states
  - `current_spatial_latitude` & `current_spatial_longitude` - GPS coordinates

**Validation Constraints:**
- Latitude must be between -90 and +90
- Longitude must be between -180 and +180
- Location updates only allowed in specific states
- Timestamps must be ordered chronologically

### Acceptance Criteria
```
Scenario 1: Tracking during delivery
  Given: Order is in "Picked Up" state
  And: Delivery partner's mobile app sends GPS update
  When: System receives location coordinates (12.9716, 77.5946)
  Then: Location is recorded with timestamp
  And: Customer can retrieve current location via tracking API
  And: Location history is maintained

Scenario 2: No tracking before pickup
  Given: Order is in "Accepted by Restaurant" state (being prepared)
  When: Delivery app attempts to send location coordinates
  Then: System rejects the update
  And: No location is recorded for this state
```

---

## Rule 3: Order State Progression Validation

**Requirement ID:** ORDER-001  
**Priority:** High  
**Category:** Workflow Enforcement

### Business Context
Orders follow a defined state progression to ensure:
- Consistent tracking across systems
- Predictable customer experience
- Proper data validation at each step
- Prevention of invalid state transitions

### Valid State Progression
```
Order Placed → Confirmed → Accepted by Restaurant → Preparation 
→ Ready for Pickup → Picked Up → Arrived at Location → Delivered
```

**Alternative Path:** Any state → Cancelled (if customer or restaurant cancels)

### Invalid Transitions (MUST BE PREVENTED)
- ❌ Cannot skip states (e.g., Order Placed → Preparation)
- ❌ Cannot move backward in progression (e.g., Preparation → Confirmed)
- ❌ Cannot deliver without "Arrived at Location" state

### Acceptance Criteria
```
Scenario 1: Valid state transition
  Given: Order is in "Confirmed" state
  When: Restaurant accepts the order
  Then: Order state changes to "Accepted by Restaurant"
  
Scenario 2: Invalid backward transition
  Given: Order is in "Preparation" state
  When: System attempts to move order back to "Confirmed" state
  Then: Update is rejected with error: "Cannot move order backward in progression"
```

---

## Rule 4: Payment Status Reconciliation

**Requirement ID:** PAYMENT-001  
**Priority:** Critical  
**Category:** Financial Transaction Management

### Business Context
Ensure all payments are successfully processed before order fulfillment begins. This protects:
- Company revenue (no fulfillment without payment)
- Customer trust (no charging without service)
- Reconciliation and audit trails

### Functional Rule
Orders cannot progress to fulfillment stages without confirmed successful payment.

**Critical Order States (Require Payment Success):**
- Preparation
- Ready for Pickup
- Picked Up
- Arrived at Location
- Delivered

### Payment Status Lifecycle
```
PENDING → SUCCESS (payment cleared) → Order can proceed
PENDING → FAILED (payment declined) → Customer must retry
PENDING → RETRY_REQUIRED (suspicious) → Manual review
```

### Acceptance Criteria
```
Scenario 1: Successful payment flow
  Given: Customer completes payment
  And: Payment gateway returns SUCCESS status
  When: Restaurant receives order
  Then: Order state can progress to "Preparation"
  
Scenario 2: Failed payment blocking fulfillment
  Given: Payment status is "FAILED"
  When: System attempts to move order to "Preparation"
  Then: Update is rejected with error: "Payment not completed"
```

---

## Implementation Guidelines

### For Database Developers
1. Implement all constraints at table level (CHECK, FOREIGN KEY, UNIQUE)
2. Create indexes on frequently queried columns
3. Run audit queries weekly to detect violations
4. Log any constraint violations for investigation

### For Application Developers
1. Mirror all validation rules at application layer
2. Provide clear error messages when validation fails
3. Prevent users from performing invalid actions in UI
4. Log all validation failures for debugging

---

**Last Updated:** June 2026  
**Total Rules:** 4  
**Coverage:** Cart Management, Tracking, Order Workflow, Payments
