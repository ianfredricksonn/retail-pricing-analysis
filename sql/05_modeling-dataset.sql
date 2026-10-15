-- ============================================================
-- 05_modeling_dataset.sql
-- Retail Pricing & Profitability Analysis
--
-- Purpose:
-- Create analysis-ready datasets from clean_sales for use in R.
-- Primary unit of observation: product-month.
--
-- Intended analysis:
--   - Price / quantity relationships
--   - Demand estimation
--   - Price elasticity
--   - Product and time controls
--   - Revenue implications
--
-- Notes:
-- clean_sales remains unchanged.
-- Queries in this script aggregate the transaction-level data
-- into datasets suitable for statistical modeling.
-- ============================================================
-- SECTION 1: PRODUCT-MONTH MODELING DATASET
-- ============================================================

-- Aggregate transaction-level sales into product-month observations.
-- Each row represents one product in one calendar month.
--
-- avg_price is the quantity-weighted average selling price:
-- total revenue / total units sold.
--
-- Additional price statistics are retained to identify product-months
-- containing substantial within-month price variation.

SELECT
    DATE_TRUNC('month', invoice_date) AS month,
    stock_code,
    description,

    COUNT(DISTINCT invoice) AS orders,
    COUNT(DISTINCT NULLIF(TRIM(customer_id), '')) AS customers,

    SUM(quantity) AS units_sold,

    ROUND(
        SUM(revenue) / NULLIF(SUM(quantity), 0),
        2
    ) AS avg_price,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)::numeric,
        2
    ) AS median_price,

    ROUND(MIN(price), 2) AS min_price,
    ROUND(MAX(price), 2) AS max_price,
    ROUND(STDDEV(price), 2) AS price_sd,

    ROUND(
        SUM(revenue),
        2
    ) AS gross_sales_revenue

FROM clean_sales

GROUP BY
    DATE_TRUNC('month', invoice_date),
    stock_code,
    description

ORDER BY
    month,
    stock_code;
-- ============================================================
-- PRODUCT-MONTH DATASET DIAGNOSTICS
-- ============================================================

WITH product_month AS (
    SELECT
        DATE_TRUNC('month', invoice_date) AS month,
        stock_code,
        description,
        COUNT(DISTINCT invoice) AS orders,
        COUNT(DISTINCT NULLIF(TRIM(customer_id), '')) AS customers,
        SUM(quantity) AS units_sold,

        SUM(revenue) / NULLIF(SUM(quantity), 0) AS avg_price,

        SUM(revenue) AS gross_sales_revenue

    FROM clean_sales

    GROUP BY
        DATE_TRUNC('month', invoice_date),
        stock_code,
        description
)

SELECT
    COUNT(*) AS product_month_observations,
    COUNT(DISTINCT stock_code) AS unique_products,
    COUNT(DISTINCT month) AS months,

    ROUND(AVG(units_sold), 2) AS avg_monthly_units,
    MIN(units_sold) AS min_monthly_units,
    MAX(units_sold) AS max_monthly_units,

    ROUND(AVG(avg_price), 2) AS avg_product_price,
    ROUND(MIN(avg_price), 2) AS min_product_price,
    ROUND(MAX(avg_price), 2) AS max_product_price,

    ROUND(AVG(orders), 2) AS avg_monthly_orders,
    MIN(orders) AS min_monthly_orders,
    MAX(orders) AS max_monthly_orders

FROM product_month;

-- ============================================================
-- WITHIN-PRODUCT PRICE VARIATION
-- ============================================================

WITH product_month AS (
    SELECT
        DATE_TRUNC('month', invoice_date) AS month,
        stock_code,
        description,
        COUNT(DISTINCT invoice) AS orders,
        SUM(quantity) AS units_sold,

        SUM(revenue) / NULLIF(SUM(quantity), 0) AS avg_price,

        SUM(revenue) AS gross_sales_revenue

    FROM clean_sales

    GROUP BY
        DATE_TRUNC('month', invoice_date),
        stock_code,
        description
),

product_price_stats AS (
    SELECT
        stock_code,
        MAX(description) AS description,

        COUNT(*) AS months_observed,

        ROUND(AVG(avg_price), 2) AS mean_price,
        ROUND(MIN(avg_price), 2) AS min_price,
        ROUND(MAX(avg_price), 2) AS max_price,

        ROUND(
            STDDEV_SAMP(avg_price),
            2
        ) AS price_sd,

        ROUND(
            100.0 * STDDEV_SAMP(avg_price)
            / NULLIF(AVG(avg_price), 0),
            2
        ) AS price_cv_pct,

        SUM(units_sold) AS total_units,
        SUM(orders) AS total_orders

    FROM product_month

    WHERE avg_price > 0

    GROUP BY stock_code
)

SELECT *
FROM product_price_stats

WHERE months_observed >= 6

ORDER BY price_cv_pct DESC NULLS LAST;

-- ============================================================
-- INVESTIGATE EXTREME PRICE VARIATION: STOCK CODE 22502
-- ============================================================

SELECT
    invoice,
    invoice_date,
    stock_code,
    description,
    quantity,
    price,
    revenue,
    customer_id,
    country

FROM clean_sales

WHERE stock_code = '22502'

ORDER BY price DESC, invoice_date;

-- ============================================================
-- STOCK CODES WITH MULTIPLE DESCRIPTIONS
-- ============================================================

SELECT
    stock_code,
    COUNT(DISTINCT description) AS description_count,
    COUNT(*) AS transaction_lines,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(
        MAX(price) / NULLIF(MIN(price), 0),
        2
    ) AS max_min_price_ratio

FROM clean_sales

WHERE price > 0

GROUP BY stock_code

HAVING COUNT(DISTINCT description) > 1

ORDER BY
    max_min_price_ratio DESC NULLS LAST;