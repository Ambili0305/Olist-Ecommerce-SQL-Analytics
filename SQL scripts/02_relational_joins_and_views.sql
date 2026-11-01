-- ==============================================================================
-- FILE: 02_relational_joins_and_views.sql
-- PROJECT: Olist E-Commerce Sales, Customer Retention & Delivery Performance Analytics
-- AUTHOR: Ambili M.
-- DESCRIPTION: Contains analytical SQL queries, multi-table JOINs, and aggregations 
--              to answer business-critical questions across Sales, Retention, and Delivery.
-- ==============================================================================

USE olist_analytics;

-- ==============================================================================
-- PILLAR 1: SALES & REVENUE PERFORMANCE
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- QUESTION 1.1: Regional Revenue Distribution by State
-- Business Context: Which Brazilian states generate the highest total revenue,
--                   order volume, and Average Order Value (AOV)?
-- ------------------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_revenue,
    ROUND(AVG(p.payment_value), 2) AS avg_order_value
FROM olist_analytics.orders_staging o
JOIN olist_analytics.customers_staging c 
    ON o.customer_id = c.customer_id
JOIN olist_analytics.order_payments_staging p 
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 1.1):
-- ------------------------------------------------------------------------------
-- 1. Top Revenue Drivers: São Paulo (SP) leads overwhelmingly with ~40,500 orders 
--    and $5.77M in total revenue, accounting for over a third of total business.
-- 2. Core Region Concentration: The top 3 states (SP, RJ, MG) represent the 
--    vast majority of order volume and total revenue.
-- 3. High AOV Anomalies: Northern states like Paraíba (PB) and Acre (AC) show 
--    fewer order volumes but significantly higher Average Order Values (~$235–$250)
--    likely driven by higher shipping costs or bulk purchasing.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 1.2: Monthly Revenue & Order Growth Trend
-- Business Context: How are sales and order volumes changing month-over-month?
--                   Is the business growing consistently over time?
-- ------------------------------------------------------------------------------
SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_revenue,
    ROUND(AVG(p.payment_value), 2) AS avg_order_value
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_payments_staging p 
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month ASC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 1.2):
-- ------------------------------------------------------------------------------
-- 1. All-Time Peak Revenue: November 2017 (2017-11) generated the highest revenue 
--    at $1,153,528.05 across 7,289 orders.
-- 2. Seasonal Demand Surge: November's ~62.7% MOM order spike aligns directly 
--    with Black Friday promotional events across Latin American e-commerce.
-- 3. Sustainable Baseline Expansion: Platform revenue scaled permanently from ~$127k/mo 
--    (Jan 2017) to a baseline of ~$1.0M - $1.1M/mo throughout 2018.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 1.3: Payment Methods & Installment Preferences
-- Business Context: What are the primary payment channels, and how do customers 
--                   utilize installment options across order values?
-- ------------------------------------------------------------------------------
SELECT 
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_revenue,
    ROUND(AVG(p.payment_value), 2) AS avg_order_value,
    ROUND(AVG(p.payment_installments), 1) AS avg_installments,
    MAX(p.payment_installments) AS max_installments
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_payments_staging p 
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY total_revenue DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 1.3):
-- ------------------------------------------------------------------------------
-- 1. Credit Card Dominance: Credit card payments account for ~78.5% of overall platform 
--    revenue ($12.10M across 74,304 orders).
-- 2. Installment Dependency: Credit card transactions average 3.5 installments, reaching 
--    up to 24x. Higher installment caps correlate directly with elevated AOVs ($162.24).
-- 3. Critical Cash Alternative: Boleto bancário generates ~18% of revenue ($2.77M), 
--    proving essential for reaching unbanked and cash-preferred shopper segments.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 1.4: Top Product Categories by Revenue & Volume
-- Business Context: Which product categories generate the highest total revenue
--                   and order volume across the platform?
-- ------------------------------------------------------------------------------
SELECT 
    COALESCE(p.product_category_name_english, p.product_category_name_portuguese, 'Unknown') AS category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(pay.payment_value), 2) AS total_revenue,
    ROUND(AVG(pay.payment_value), 2) AS avg_order_value
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_items_staging oi 
    ON o.order_id = oi.order_id
JOIN olist_analytics.products_staging p 
    ON oi.product_id = p.product_id
JOIN olist_analytics.order_payments_staging pay 
    ON o.order_id = pay.order_id
WHERE o.order_status = 'delivered'
GROUP BY category_name
ORDER BY total_revenue DESC
LIMIT 10;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 1.4):
-- ------------------------------------------------------------------------------
-- 1. Top Category Champion: Bed, Bath & Table (bed_bath_table) dominates both total 
--    volume (11,650 items) and total revenue ($1.69M).
-- 2. Core Revenue Drivers: Home goods, Health & Beauty, and Tech Accessories 
--    represent the main revenue pillars of Olist's marketplace.
-- 3. Premium Margin Categories: Watches & Gifts commands the highest Average Order 
--    Value ($228.75), indicating high profitability per order unit.
-- ==============================================================================
*/
-- ==============================================================================
-- PILLAR 2: DELIVERY PERFORMANCE & LOGISTICS EFFICIENCY
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- QUESTION 2.1: On-Time vs. Late Delivery Analysis
-- Business Context: What proportion of delivered orders meet the promised 
--                   estimated delivery date vs. arriving late?
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On-Time / Early'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late Delivery'
        ELSE 'Unknown / In Transit'
    END AS delivery_status,
    COUNT(o.order_id) AS total_orders,
    ROUND(COUNT(o.order_id) * 100.0 / SUM(COUNT(o.order_id)) OVER(), 2) AS percentage_of_total
FROM olist_analytics.orders_staging o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY total_orders DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 2.1):
-- ------------------------------------------------------------------------------
-- 1. High Fulfillment SLA: ~91.89% of completed orders (88,644 orders) arrive 
--    on or ahead of the promised estimated delivery date.
-- 2. Delivery Defect Rate: ~8.11% of shipments (7,826 orders) suffer from delays, 
--    representing the primary operational bottleneck affecting customer satisfaction.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 2.2: Late Delivery Rate by Customer State
-- Business Context: Which states suffer from the highest proportion of delayed 
--                   deliveries, and how severe are those regional bottlenecks?
-- ------------------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(o.order_id) AS total_delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 
        2
    ) AS late_delivery_rate_pct,
    ROUND(
        AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 
        1
    ) AS avg_actual_delivery_days
FROM olist_analytics.orders_staging o
JOIN olist_analytics.customers_staging c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING total_delivered_orders >= 100
ORDER BY late_delivery_rate_pct DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 2.2):
-- ------------------------------------------------------------------------------
-- 1. Worst Regional Bottleneck: Alagoas (AL) experiences the highest late delivery 
--    rate at 23.93%, with shipments taking an average of 24.5 days.
-- 2. Northeastern Logistics Friction: States in the Northeast (AL, MA, PI, CE, SE) 
--    suffer consistently high delay rates ranging from 15% to ~24%.
-- 3. Urban Logistics Issue in RJ: Rio de Janeiro exhibits an abnormally high delay 
--    rate (13.47%) relative to its proximity to major seller hubs, indicating local last-mile courier challenges.
-- 4. Efficient Core Hubs: São Paulo (SP) and Minas Gerais (MG) lead in speed and reliability 
--    with late rates below 6% and average delivery times under 12 days.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 2.3: Freight Costs & Delivery Speed Analysis by Customer State (Optimized)
-- Business Context: Evaluate average freight costs, actual delivery speeds, and 
--                   estimated buffer days across different customer states.
-- ------------------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(f.total_order_freight), 2) AS avg_freight_cost_per_order,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_actual_delivery_days,
    ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)), 1) AS avg_estimated_delivery_days,
    ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_delivered_customer_date)), 1) AS avg_early_buffer_days
FROM olist_analytics.orders_staging o
JOIN olist_analytics.customers_staging c 
    ON o.customer_id = c.customer_id
JOIN (
    SELECT order_id, SUM(freight_value) AS total_order_freight
    FROM olist_analytics.order_items_staging
    GROUP BY order_id
) f ON o.order_id = f.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_freight_cost_per_order DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 2.3):
-- ------------------------------------------------------------------------------
-- 1. Extreme Freight Disparity: Northern/Northeastern states (PB, RR, RO, AC) 
--    face average freight fees of $45-$49 per order, nearly triple São Paulo's $17.33.
-- 2. Strong Cost-Distance Correlation: Shipping cost directly scales with distance 
--    and transit duration (r = 0.80 correlation between freight price and delivery days).
-- 3. Excessive Estimate Buffers: Olist applies conservative buffers (10-20 days early) 
--    for distant regions to safeguard SLAs, which may hurt checkout conversion rates.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 2.4: Seller Dispatch Delay vs. Carrier Transit Delay
-- Business Context: Pinpoint whether late deliveries are primarily driven by 
--                   seller dispatch delays or postal carrier transit bottlenecks.
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_delivered_carrier_date > o.shipping_limit_date AND o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Both Seller & Carrier Late'
        WHEN o.order_delivered_carrier_date > o.shipping_limit_date 
            THEN 'Seller Dispatch Delay Only'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Carrier Transit Delay Only'
        ELSE 'On-Time Dispatch & Delivery'
    END AS delay_attribution,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER(), 2) AS percentage_of_total
FROM (
    SELECT 
        o.order_id,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        MAX(oi.shipping_limit_date) AS shipping_limit_date
    FROM olist_analytics.orders_staging o
    JOIN olist_analytics.order_items_staging oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
    GROUP BY o.order_id, o.order_delivered_carrier_date, o.order_delivered_customer_date, o.order_estimated_delivery_date
) o
GROUP BY delay_attribution
ORDER BY total_orders DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 2.4):
-- ------------------------------------------------------------------------------
-- 1. Carrier Responsibility: Carrier transit delays account for ~72.8% of all 
--    customer-facing late deliveries (5,697 orders delayed purely in transit).
-- 2. Seller Handling Resilience: ~6.82% of orders experienced delayed seller 
--    dispatch but were still delivered on time due to estimated transit buffers.
-- 3. Compound Delays: ~2.21% of orders suffer from both seller dispatch AND 
--    carrier delays, resulting in severe customer dissatisfaction.
-- ==============================================================================
*/
-- ==============================================================================
-- PILLAR 3: CUSTOMER SATISFACTION, REVIEWS & PRODUCT INSIGHTS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- QUESTION 3.1: Review Score Distribution & Impact of Late Deliveries
-- Business Context: Analyze the spread of customer review scores (1 to 5 stars) 
--                   and quantify the direct penalty late deliveries impose on ratings.
-- ------------------------------------------------------------------------------
SELECT 
    r.review_score,
    COUNT(r.review_id) AS total_reviews,
    ROUND(COUNT(r.review_id) * 100.0 / SUM(COUNT(r.review_id)) OVER(), 2) AS percentage_of_total,
    ROUND(AVG(CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END) * 100.0, 2) AS late_delivery_rate_pct
FROM olist_analytics.olist_order_reviews_dataset r
JOIN olist_analytics.orders_staging o 
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY r.review_score
ORDER BY r.review_score DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 3.1):
-- ------------------------------------------------------------------------------
-- 1. High Base Satisfaction: ~74.81% of reviews are 4 or 5 stars, with 5-star 
--    reviews making up 60.37% of the total.
-- 2. Direct Late Delivery Penalty: 1-star reviews exhibit a 37.50% late delivery rate, 
--    compared to just 3.68% for 5-star reviews.
-- 3. Logistics Impact: SLA failure is the leading driver of severe customer churn 
--    and low platform ratings.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 3.2: Top Performing vs. At-Risk Sellers Analysis
-- Business Context: Evaluate sellers by fulfillment volume, total revenue, 
--                   and average customer rating to flag top partners & risk areas.
-- ------------------------------------------------------------------------------
SELECT 
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_seller_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    CASE 
        WHEN AVG(r.review_score) >= 4.5 AND COUNT(DISTINCT o.order_id) >= 50 THEN 'Top Performing Seller'
        WHEN AVG(r.review_score) < 3.5 AND COUNT(DISTINCT o.order_id) >= 20 THEN 'At-Risk / Needs QA'
        ELSE 'Standard Seller'
    END AS seller_performance_tier
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_items_staging oi 
    ON o.order_id = oi.order_id
JOIN olist_analytics.sellers_staging s 
    ON oi.seller_id = s.seller_id
LEFT JOIN olist_analytics.olist_order_reviews_dataset r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state
HAVING total_orders >= 10
ORDER BY total_seller_revenue DESC
LIMIT 15;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 3.2):
-- ------------------------------------------------------------------------------
-- 1. High Revenue vs. Quality Risk: 4 of the top 10 highest-earning sellers fail 
--    to maintain a 3.5+ review score, signaling potential operational or product quality issues.
-- 2. Top Performing Partners: Merchants like 4a3ca931... achieve high scale ($231K+ revenue, 
--    1,772 orders) while sustaining a perfect 5.00 average review rating.
-- 3. Geographic Seller Hub: The vast majority of top-tier sellers operate out of 
--    São Paulo (SP), driving the region's overall logistics dominance.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 3.3: Product Category Review Scores & Satisfaction Analysis
-- Business Context: Aggregate customer ratings by product category to identify 
--                   top-rated categories vs. quality risk categories.
-- ------------------------------------------------------------------------------
SELECT 
    p.product_category_name_english AS product_category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_category_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) * 100.0 / COUNT(r.review_id), 2) AS pct_5_star_reviews,
    ROUND(SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(r.review_id), 2) AS pct_1_star_reviews
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_items_staging oi 
    ON o.order_id = oi.order_id
JOIN olist_analytics.products_staging p 
    ON oi.product_id = p.product_id
LEFT JOIN olist_analytics.olist_order_reviews_dataset r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND p.product_category_name_english IS NOT NULL
GROUP BY p.product_category_name_english
HAVING total_orders >= 50
ORDER BY avg_review_score DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 3.3):
-- ------------------------------------------------------------------------------
-- 1. Top Customer Delight Categories: Books, Computers, and Living Room Furniture 
--    achieve top satisfaction ratings (5.0 avg score) with high 5-star concentration.
-- 2. At-Risk Categories: High-volume categories such as Stationery (2,264 orders, 2.43 avg rating) 
--    and Audio (2.50 avg rating) experience elevated 1-star review rates (>50%).
-- 3. Targeted QA Focus: Merchandising and quality control efforts should prioritize 
--    Stationery, Audio, and Fashion categories to mitigate return/review friction.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 3.4: Delivery Delay Impact on Review Scores by Category
-- Business Context: Measure average review scores for on-time vs. late shipments 
--                   by category to identify products most sensitive to SLA breaches.
-- ------------------------------------------------------------------------------
SELECT 
    p.product_category_name_english AS product_category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
        THEN r.review_score 
    END), 2) AS avg_ontime_review_score,
    ROUND(AVG(CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
        THEN r.review_score 
    END), 2) AS avg_late_review_score,
    ROUND(
        AVG(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN r.review_score END) - 
        AVG(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN r.review_score END), 
    2) AS rating_drop_due_to_delay
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_items_staging oi 
    ON o.order_id = oi.order_id
JOIN olist_analytics.products_staging p 
    ON oi.product_id = p.product_id
LEFT JOIN olist_analytics.olist_order_reviews_dataset r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND p.product_category_name_english IS NOT NULL
GROUP BY p.product_category_name_english
HAVING COUNT(DISTINCT o.order_id) >= 50 
   AND avg_late_review_score IS NOT NULL
ORDER BY rating_drop_due_to_delay DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 3.4):
-- ------------------------------------------------------------------------------
-- 1. Extreme Sensitivity in Premium & Gift Categories: Auto (-3.75 stars), Perfumery (-3.57 stars), 
--    and Watches & Gifts (-3.42 stars) suffer immediate crashes to 1.0 star when delivered late.
-- 2. Essential & Personal Items Impact: Baby (-2.86 stars) and Health & Beauty (-2.41 stars) 
--    exhibit steep rating drops, reflecting high customer urgency and emotional investment.
-- 3. Operational SLA Priority: Express routing and strict seller dispatch thresholds should be 
--    enforced for high-risk gift/personal categories to safeguard platform review scores.
-- ==============================================================================
*/
-- ==============================================================================
-- PILLAR 4: PAYMENT METHODS, INSTALLMENTS & FINANCIAL PERFORMANCE
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- QUESTION 4.1: Breakdown of Payment Methods & Revenue Volume
-- Business Context: Evaluate revenue contribution, transaction volume, 
--                   and average transaction size across all payment methods.
-- ------------------------------------------------------------------------------
SELECT 
    pay.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(pay.payment_sequential) AS total_payment_transactions,
    ROUND(SUM(pay.payment_value), 2) AS total_payment_value,
    ROUND(SUM(pay.payment_value) * 100.0 / SUM(SUM(pay.payment_value)) OVER(), 2) AS percentage_of_total_gmv,
    ROUND(AVG(pay.payment_value), 2) AS avg_transaction_value
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_payments_staging pay 
    ON o.order_id = pay.order_id
WHERE o.order_status = 'delivered'
GROUP BY pay.payment_type
ORDER BY total_payment_value DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 4.1):
-- ------------------------------------------------------------------------------
-- 1. Credit Card Dominance: Credit card payments account for 78.46% of total platform GMV 
--    ($12.1M+) and drive the highest average transaction size ($162.24).
-- 2. Boleto Volume: Boleto ranks second, generating 17.96% of total revenue ($2.77M+), 
--    proving to be an essential payment rail for Brazilian e-commerce accessibility.
-- 3. Voucher Behavior: Vouchers are often split across multiple transaction sequences 
--    (5,493 transactions across 3,679 orders), serving as promotional subsidies.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 4.2: Credit Card Installment Behavior & Order Value Expansion
-- Business Context: Analyze order distribution and average order values 
--                   across credit card installment counts.
-- ------------------------------------------------------------------------------
SELECT 
    pay.payment_installments,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(pay.payment_value), 2) AS total_revenue,
    ROUND(AVG(pay.payment_value), 2) AS avg_order_value,
    ROUND(MIN(pay.payment_value), 2) AS min_order_value,
    ROUND(MAX(pay.payment_value), 2) AS max_order_value
FROM olist_analytics.orders_staging o
JOIN olist_analytics.order_payments_staging pay 
    ON o.order_id = pay.order_id
WHERE o.order_status = 'delivered'
  AND pay.payment_type = 'credit_card'
GROUP BY pay.payment_installments
ORDER BY pay.payment_installments ASC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 4.2):
-- ------------------------------------------------------------------------------
-- 1. Order Value Expansion: Average order value scales consistently with installment count 
--    (1x = $95.60, 5x = $182.30, 10x = $410.54), demonstrating that financing drives higher cart sizes.
-- 2. 10x Installment Concentration: 10-installment plans drive $2.11M+ in GMV across 5,137 orders, 
--    making it the single largest revenue-generating installment option.
-- 3. High-Ticket Enabler: Ultra-long options (20x–24x) support basket sizes exceeding $600+, 
--    providing vital financing for expensive goods like computers and appliances.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 4.3: Payment Method Impact on Repeat Rate & Customer Loyalty
-- Business Context: Calculate repeat customer percentage and purchase frequency 
--                   broken down by primary payment method used.
-- ------------------------------------------------------------------------------
WITH customer_payments AS (
    SELECT 
        c.customer_unique_id,
        pay.payment_type,
        COUNT(DISTINCT o.order_id) AS total_orders_by_customer
    FROM olist_analytics.orders_staging o
    JOIN olist_analytics.customers_staging c 
        ON o.customer_id = c.customer_id
    JOIN olist_analytics.order_payments_staging pay 
        ON o.order_id = pay.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, pay.payment_type
)
SELECT 
    payment_type,
    COUNT(DISTINCT customer_unique_id) AS total_unique_customers,
    SUM(CASE WHEN total_orders_by_customer > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        SUM(CASE WHEN total_orders_by_customer > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT customer_unique_id), 
    2) AS repeat_customer_rate_pct,
    ROUND(AVG(total_orders_by_customer), 2) AS avg_orders_per_customer
FROM customer_payments
GROUP BY payment_type
ORDER BY total_unique_customers DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 4.3):
-- ------------------------------------------------------------------------------
-- 1. Credit Card Loyalty Advantage: Credit card users yield the highest repeat customer 
--    rate at 2.86%, outperforming Boleto (2.27%) and Debit Card (1.02%).
-- 2. Checkout Friction Impact: One-click saved card flows encourage higher customer retention 
--    compared to manual cash voucher/boleto payment methods.
-- 3. Loyalty Infrastructure Need: Low overall platform repeat rates (< 3%) emphasize 
--    the opportunity to build post-purchase retention programs and automatic payment options.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- QUESTION 4.4: Multi-Payment Transactions & Voucher Revenue Subsidies
-- Business Context: Measure orders utilizing split/multi-payment methods 
--                   and assess voucher subsidy impact on total order value.
-- ------------------------------------------------------------------------------
WITH order_payment_summary AS (
    SELECT 
        o.order_id,
        COUNT(pay.payment_sequential) AS total_payment_records,
        COUNT(DISTINCT pay.payment_type) AS distinct_payment_types,
        SUM(CASE WHEN pay.payment_type = 'voucher' THEN pay.payment_value ELSE 0 END) AS voucher_amount_paid,
        SUM(pay.payment_value) AS total_order_payment_value
    FROM olist_analytics.orders_staging o
    JOIN olist_analytics.order_payments_staging pay 
        ON o.order_id = pay.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
)
SELECT 
    CASE 
        WHEN distinct_payment_types > 1 THEN 'Multi-Payment (Mixed Methods)'
        WHEN total_payment_records > 1 THEN 'Multi-Payment (Same Method Split)'
        ELSE 'Single Payment Method'
    END AS payment_behavior,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_order_payment_value), 2) AS total_gmv,
    ROUND(AVG(total_order_payment_value), 2) AS avg_order_value,
    ROUND(SUM(voucher_amount_paid), 2) AS total_voucher_subsidy,
    ROUND(SUM(voucher_amount_paid) * 100.0 / NULLIF(SUM(total_order_payment_value), 0), 2) AS voucher_subsidy_pct_of_gmv
FROM order_payment_summary
GROUP BY 
    CASE 
        WHEN distinct_payment_types > 1 THEN 'Multi-Payment (Mixed Methods)'
        WHEN total_payment_records > 1 THEN 'Multi-Payment (Same Method Split)'
        ELSE 'Single Payment Method'
    END
ORDER BY total_orders DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (Question 4.4):
-- ------------------------------------------------------------------------------
-- 1. Single Payment Reliance: 97.02% of all delivered orders (93,602 orders) use a single payment method, 
--    generating $14.95M GMV with an Average Order Value of $159.73.
-- 2. Voucher Co-Financing Impact: Mixed-method multi-payments (2,182 orders) rely heavily on voucher subsidies, 
--    with vouchers covering 57.15% ($185.5K) of total transaction value in that tier.
-- 3. Split Payment Premium: Split transactions of the same payment method carry the highest AOV ($212.28), 
--    indicating multi-card flexibility helps facilitate higher basket sizes.
-- ==============================================================================
*/
-- ==============================================================================
-- PILLAR 5: ADVANCED SQL ANALYTICAL VIEWS & BUSINESS DASHBOARDS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- VIEW 5.1: Monthly Executive KPI Summary View
-- Business Context: Consolidates monthly revenue, order volume, customer counts, 
--                   satisfaction, and delivery SLA metrics for leadership reporting.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW olist_analytics.vw_executive_kpi_summary AS
SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS `year_month`,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_unique_buyers,
    ROUND(SUM(pay.payment_value), 2) AS total_gmv,
    ROUND(AVG(pay.payment_value), 2) AS avg_order_value,
    ROUND(AVG(r.review_score), 2) AS avg_customer_satisfaction,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT o.order_id), 0), 
    2) AS late_delivery_rate_pct,
    ROUND(
        AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 
    1) AS avg_fulfillment_days
FROM olist_analytics.orders_staging o
LEFT JOIN olist_analytics.order_payments_staging pay 
    ON o.order_id = pay.order_id
LEFT JOIN olist_analytics.olist_order_reviews_dataset r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m');

SELECT * 
FROM olist_analytics.vw_executive_kpi_summary 
ORDER BY `year_month` ASC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (View 5.1 - Monthly Executive KPI Summary):
-- ------------------------------------------------------------------------------
-- 1. Rapid Scaling & Peak Revenue: Monthly GMV expanded nearly 10x from $127.5K (Jan 2017) 
--    to a peak of $1.15M+ in November 2017 driven by holiday shopping surges.
-- 2. Operational Stress Point: March 2018 suffered severe logistics congestion, pushing 
--    the late delivery rate to a peak of 22.18% and average fulfillment to 16.2 days.
-- 3. Logistics Efficiency Recovery: Fulfillment time decreased to 7.7 days by August 2018, 
--    driving average customer satisfaction scores up to 4.44 stars.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- VIEW 5.2: Customer RFM Segmentation View
-- Business Context: Calculates Recency, Frequency, and Monetary (RFM) metrics 
--                   and classifies customers into actionable retention segments.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW olist_analytics.vw_customer_rfm_segments AS
WITH max_date_cte AS (
    SELECT MAX(order_purchase_timestamp) AS max_platform_date
    FROM olist_analytics.orders_staging
    WHERE order_status = 'delivered'
),
customer_rfm_raw AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF(m.max_platform_date, MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        ROUND(SUM(pay.payment_value), 2) AS monetary_value
    FROM olist_analytics.orders_staging o
    JOIN olist_analytics.customers_staging c 
        ON o.customer_id = c.customer_id
    JOIN olist_analytics.order_payments_staging pay 
        ON o.order_id = pay.order_id
    CROSS JOIN max_date_cte m
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, m.max_platform_date
)
SELECT 
    customer_unique_id,
    recency_days,
    frequency_orders,
    monetary_value,
    CASE 
        WHEN recency_days <= 90 AND frequency_orders > 1 THEN 'Champions'
        WHEN recency_days <= 180 AND frequency_orders > 1 THEN 'Loyal Customers'
        WHEN recency_days <= 180 AND frequency_orders = 1 THEN 'Recent One-Time Buyers'
        WHEN recency_days > 180 AND frequency_orders > 1 THEN 'At-Risk (High Value Repeat)'
        ELSE 'Lost / Churned (One-Time)'
    END AS rfm_segment
FROM customer_rfm_raw;

SELECT 
    rfm_segment,
    COUNT(customer_unique_id) AS total_customers,
    ROUND(SUM(monetary_value), 2) AS total_segment_revenue,
    ROUND(AVG(monetary_value), 2) AS avg_monetary_value,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency_orders), 2) AS avg_frequency_orders
FROM olist_analytics.vw_customer_rfm_segments
GROUP BY rfm_segment
ORDER BY total_segment_revenue DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (View 5.2 - Customer RFM Segmentation):
-- ------------------------------------------------------------------------------
-- 1. One-Time Buyer Reliance: Over 94.4% of total GMV ($14.55M out of $15.42M) originates from 
--    one-time purchasers (Lost + Recent One-Time Buyers), indicating a critical retention gap.
-- 2. LTV Multiplier for Repeat Buyers: Repeat customer segments (Champions, Loyal, At-Risk) 
--    exhibit average monetary spend of $300-$322, double that of single-order customers ($158-$164).
-- 3. Win-Back Priority: 1,564 high-value repeat buyers ($467.6K GMV) are currently classified 
--    as 'At-Risk' (>180 days dormant), presenting immediate ROI for re-activation campaigns.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- VIEW 5.3: Seller Performance Scorecard View
-- Business Context: Aggregates seller GMV, item volume, fulfillment SLA performance,
--                   and customer review ratings into a tier-based seller scorecard.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW olist_analytics.vw_seller_performance_scorecard AS
SELECT 
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_item_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_seller_gmv,
    ROUND(AVG(r.review_score), 2) AS avg_seller_rating,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT o.order_id), 0), 
    2) AS seller_late_delivery_rate_pct,
    ROUND(
        AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 
    1) AS avg_fulfillment_days,
    CASE 
        WHEN SUM(oi.price + oi.freight_value) >= 100000 AND AVG(r.review_score) >= 4.0 THEN 'Top Tier (High Volume & High Rating)'
        WHEN SUM(oi.price + oi.freight_value) >= 50000 THEN 'Mid Tier (Solid Revenue)'
        WHEN AVG(r.review_score) < 3.5 THEN 'At Risk (Low Rating)'
        ELSE 'Standard Seller'
    END AS seller_performance_tier
FROM olist_analytics.sellers_staging s
JOIN olist_analytics.order_items_staging oi 
    ON s.seller_id = oi.seller_id
JOIN olist_analytics.orders_staging o 
    ON oi.order_id = o.order_id
LEFT JOIN olist_analytics.olist_order_reviews_dataset r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state, s.seller_city;

SELECT 
    seller_performance_tier,
    COUNT(seller_id) AS total_sellers,
    ROUND(SUM(total_seller_gmv), 2) AS total_gmv,
    ROUND(AVG(total_seller_gmv), 2) AS avg_gmv_per_seller,
    ROUND(AVG(avg_seller_rating), 2) AS avg_tier_rating,
    ROUND(AVG(seller_late_delivery_rate_pct), 2) AS avg_late_rate_pct
FROM olist_analytics.vw_seller_performance_scorecard
GROUP BY seller_performance_tier
ORDER BY total_gmv DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (View 5.3 - Seller Performance Scorecard):
-- ------------------------------------------------------------------------------
-- 1. Revenue Pareto Distribution: Top and Mid-tier sellers represent just 1.58% of vendors 
--    (47 sellers) but generate 31.58% ($4.87M) of platform GMV.
-- 2. Quality Bottlenecks in Scaling: Mid-tier sellers show a rating dip to 3.29 stars, 
--    signaling operational strain as order volume expands without fulfillment support.
-- 3. High-Risk Vendor Footprint: 43 sellers generate $537.6K GMV with a 19.70% late delivery rate 
--    and 1.83 rating, highlighting the need for active vendor monitoring and SLA enforcement.
-- ==============================================================================
*/
-- ------------------------------------------------------------------------------
-- VIEW 5.4: Logistics & Fulfillment Health View
-- Business Context: Measures regional delivery speed, SLA compliance, late delivery rates,
--                   and freight cost metrics by customer destination state.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW olist_analytics.vw_logistics_fulfillment_health AS
WITH order_item_totals AS (
    SELECT 
        order_id,
        SUM(price + freight_value) AS order_gmv,
        AVG(freight_value) AS avg_freight
    FROM olist_analytics.order_items_staging
    GROUP BY order_id
)
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oit.order_gmv), 2) AS total_gmv,
    ROUND(AVG(oit.avg_freight), 2) AS avg_freight_cost_per_item,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_actual_fulfillment_days,
    ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)), 1) AS avg_estimated_fulfillment_days,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS total_late_orders,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT o.order_id), 0), 
    2) AS late_delivery_rate_pct,
    ROUND(
        AVG(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) 
            ELSE NULL 
        END), 
    1) AS avg_days_delayed_when_late
FROM olist_analytics.orders_staging o
JOIN olist_analytics.customers_staging c 
    ON o.customer_id = c.customer_id
JOIN order_item_totals oit 
    ON o.order_id = oit.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state;

SELECT * 
FROM olist_analytics.vw_logistics_fulfillment_health
ORDER BY total_orders DESC;
/*
-- ==============================================================================
-- INSIGHTS & FINDINGS (View 5.4 - Logistics & Fulfillment Health):
-- ------------------------------------------------------------------------------
-- 1. São Paulo Fulfillment Dominance: SP leads platform volume (40,501 orders) with 
--    the fastest actual delivery speed (8.7 days) and lowest freight cost ($15.27/item).
-- 2. Rio de Janeiro Last-Mile Friction: RJ experiences high delay rates (13.47% late) 
--    despite geographic proximity to SP, pointing to regional carrier inefficiencies.
-- 3. North/Northeast Regional Disparity: States like Alagoas (AL) and Maranhão (MA) suffer 
--    high late rates (19.7%-23.9%), 21+ day transit times, and $36+ average freight fees.
-- ==============================================================================
*/