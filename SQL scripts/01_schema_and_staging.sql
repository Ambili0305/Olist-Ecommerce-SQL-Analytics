-- ==============================================================================
-- FILE: 01_schema_and_staging.sql
-- PROJECT: Olist E-Commerce Sales, Customer Retention & Delivery Performance Analytics
-- AUTHOR: Ambili M.
-- DESCRIPTION: Complete ETL script including raw data exploration, data auditing,
--              staging table creation, date parsing, BOM artifact fixes, and 
--              row count validations across all 7 core datasets.
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS olist_analytics;
USE olist_analytics;


-- ==============================================================================
-- 1. ORDERS: EXPLORATION, AUDITING & STAGING
-- ==============================================================================
SELECT COUNT(*) FROM olist_analytics.customers_dataset;
DESCRIBE olist_analytics.orders;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM olist_analytics.orders;

-- Audit missing timestamps
SELECT
    COUNT(*) AS total_orders,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_dates,
    SUM(order_approved_at IS NULL) AS missing_approval_dates,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_dates,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated_dates
FROM olist_analytics.orders;

SELECT
    order_status,
    COUNT(*) AS total_orders,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_dates
FROM olist_analytics.orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Audit empty strings vs NULLs
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_approved_at = '' THEN 1 ELSE 0 END) AS approved_empty_strings,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS approved_nulls,
    SUM(CASE WHEN order_delivered_customer_date = '' THEN 1 ELSE 0 END) as delivered_empty_strings,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) as delivered_nulls
FROM olist_analytics.orders;

-- Create orders staging table
CREATE TABLE olist_analytics.orders_staging (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

-- Populate orders staging with NULLIF handling
INSERT INTO olist_analytics.orders_staging
SELECT 
    order_id,
    customer_id,
    order_status,
    NULLIF(order_purchase_timestamp, '') AS order_purchase_timestamp,
    NULLIF(order_approved_at, '') AS order_approved_at,
    NULLIF(order_delivered_carrier_date, '') AS order_delivered_carrier_date,
    NULLIF(order_delivered_customer_date, '') AS order_delivered_customer_date,
    NULLIF(order_estimated_delivery_date, '') AS order_estimated_delivery_date
FROM olist_analytics.orders;

-- Validate orders staging & test date math
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS approved_null_count,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS delivered_null_count,
    AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) AS avg_delivery_days
FROM olist_analytics.orders_staging;


-- ==============================================================================
-- 2. PAYMENTS STAGING
-- ==============================================================================
CREATE TABLE olist_analytics.order_payments_staging (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(10, 2)
);

INSERT INTO olist_analytics.order_payments_staging
SELECT 
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM olist_analytics.olist_order_payments_dataset;


-- ==============================================================================
-- 3. CUSTOMERS STAGING
-- ==============================================================================
CREATE TABLE olist_analytics.customers_staging (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

INSERT INTO olist_analytics.customers_staging
SELECT 
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM olist_analytics.olist_customers_dataset;


-- ==============================================================================
-- 4. ORDER ITEMS STAGING
-- ==============================================================================
CREATE TABLE olist_analytics.order_items_staging (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2)
);

INSERT INTO olist_analytics.order_items_staging
SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    STR_TO_DATE(shipping_limit_date, '%Y-%m-%d %H:%i:%s'),
    price,
    freight_value
FROM olist_analytics.olist_order_items_dataset;


-- ==============================================================================
-- 5. PRODUCTS STAGING & CATEGORY TRANSLATION FIX
-- ==============================================================================
DESCRIBE olist_analytics.product_category_name_translation;

-- Fix BOM artifact in column header
ALTER TABLE olist_analytics.product_category_name_translation 
RENAME COLUMN `ï»¿product_category_name` TO `product_category_name`;

CREATE TABLE olist_analytics.products_staging (
    product_id VARCHAR(50),
    product_category_name_portuguese VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

INSERT INTO olist_analytics.products_staging
SELECT 
    p.product_id,
    p.product_category_name AS product_category_name_portuguese,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM olist_analytics.olist_products_dataset p
LEFT JOIN olist_analytics.product_category_name_translation t
    ON p.product_category_name = t.product_category_name;

-- Verify product primary key uniqueness
SELECT COUNT(*) FROM olist_analytics.products_staging WHERE product_id IS NULL OR product_id = '';


-- ==============================================================================
-- 6. SELLERS STAGING
-- ==============================================================================
CREATE TABLE olist_analytics.sellers_staging (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

INSERT INTO olist_analytics.sellers_staging
SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM olist_analytics.olist_sellers_dataset;


-- ==============================================================================
-- 7. ORDER REVIEWS STAGING
-- ==============================================================================
CREATE TABLE olist_analytics.order_reviews_staging (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title VARCHAR(255),
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

INSERT INTO olist_analytics.order_reviews_staging
SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s')
FROM olist_analytics.olist_order_reviews_dataset;


-- ==============================================================================
-- 8. FINAL STAGING ROW COUNT VERIFICATION AUDIT
-- ==============================================================================
SELECT 
    (SELECT COUNT(*) FROM olist_analytics.orders_staging) AS orders_count,
    (SELECT COUNT(*) FROM olist_analytics.order_payments_staging) AS payments_count,
    (SELECT COUNT(*) FROM olist_analytics.customers_staging) AS customers_count,
    (SELECT COUNT(*) FROM olist_analytics.order_items_staging) AS order_items_count,
    (SELECT COUNT(*) FROM olist_analytics.products_staging) AS products_count,
    (SELECT COUNT(*) FROM olist_analytics.sellers_staging) AS sellers_count,
    (SELECT COUNT(*) FROM olist_analytics.order_reviews_staging) AS reviews_count;