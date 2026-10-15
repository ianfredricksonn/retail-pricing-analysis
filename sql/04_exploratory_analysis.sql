-- ============================================================
-- 04 EXPLORATORY ANALYSIS
-- ============================================================

-- Monthly sales performance
SELECT
    DATE_TRUNC('month', invoice_date) AS month,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue,
    ROUND(AVG(revenue), 2) AS avg_transaction_line_revenue
FROM clean_sales
GROUP BY DATE_TRUNC('month', invoice_date)
ORDER BY month;
-- Monthly order-level performance
WITH order_totals AS (
    SELECT
        invoice,
        DATE_TRUNC('month', MIN(invoice_date)) AS month,
        SUM(quantity) AS order_units,
        SUM(revenue) AS order_revenue
    FROM clean_sales
    GROUP BY invoice
)

SELECT
    month,
    COUNT(*) AS orders,
    ROUND(AVG(order_units), 2) AS avg_units_per_order,
    ROUND(AVG(order_revenue), 2) AS avg_order_value,
    ROUND(SUM(order_revenue), 2) AS gross_sales_revenue
FROM order_totals
GROUP BY month
ORDER BY month;
-- Largest orders in September 2011
SELECT
    invoice,
    customer_id,
    country,
    SUM(quantity) AS units_in_order,
    ROUND(SUM(revenue), 2) AS order_value,
    COUNT(*) AS transaction_lines
FROM clean_sales
WHERE invoice_date >= '2011-09-01'
  AND invoice_date <  '2011-10-01'
GROUP BY
    invoice,
    customer_id,
    country
ORDER BY units_in_order DESC
LIMIT 20;
-- Compare average vs. median units per order by month
WITH order_totals AS (
    SELECT
        invoice,
        DATE_TRUNC('month', MIN(invoice_date)) AS month,
        SUM(quantity) AS units_in_order
    FROM clean_sales
    GROUP BY invoice
)

SELECT
    month,
    COUNT(*) AS orders,
    ROUND(AVG(units_in_order), 2) AS avg_units_per_order,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY units_in_order)::numeric,
        2
    ) AS median_units_per_order,
    MAX(units_in_order) AS largest_order_units
FROM order_totals
GROUP BY month
ORDER BY month;

-- Investigate unusually large orders in August and September 2010
SELECT
    invoice,
    customer_id,
    country,
    MIN(invoice_date) AS order_date,
    SUM(quantity) AS units_in_order,
    ROUND(SUM(revenue), 2) AS order_value,
    COUNT(*) AS transaction_lines,
    COUNT(DISTINCT stock_code) AS unique_products
FROM clean_sales
WHERE invoice_date >= '2010-08-01'
  AND invoice_date <  '2010-10-01'
GROUP BY
    invoice,
    customer_id,
    country
ORDER BY units_in_order DESC
LIMIT 30;
-- Compare the two unusually large orders line by line
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    price,
    revenue
FROM clean_sales
WHERE invoice IN ('518505', '524174')
ORDER BY stock_code, invoice;
-- Verify whether invoices 518505 and 524174 contain identical baskets
WITH order_1 AS (
    SELECT
        stock_code,
        description,
        quantity,
        price,
        revenue
    FROM clean_sales
    WHERE invoice = '518505'
),
order_2 AS (
    SELECT
        stock_code,
        description,
        quantity,
        price,
        revenue
    FROM clean_sales
    WHERE invoice = '524174'
)

SELECT *
FROM order_1
EXCEPT
SELECT *
FROM order_2

UNION ALL

SELECT *
FROM order_2
EXCEPT
SELECT *
FROM order_1;
-- Identify which basket contains each differing line
WITH order_1 AS (
    SELECT stock_code, description, quantity, price, revenue
    FROM clean_sales
    WHERE invoice = '518505'
),
order_2 AS (
    SELECT stock_code, description, quantity, price, revenue
    FROM clean_sales
    WHERE invoice = '524174'
)

SELECT
    '518505 only' AS source,
    *
FROM (
    SELECT * FROM order_1
    EXCEPT
    SELECT * FROM order_2
) a

UNION ALL

SELECT
    '524174 only' AS source,
    *
FROM (
    SELECT * FROM order_2
    EXCEPT
    SELECT * FROM order_1
) b;
-- Investigation result:
-- The unusually large Aug/Sep 2010 orders have identical total units
-- and order values but are not exact duplicate transactions.
-- Line-level comparison found four product-description differences,
-- while quantities, prices, and revenues remained the same.
-- Orders were retained as valid distinct transactions.

-- ============================================================
-- PRODUCT PERFORMANCE
-- ============================================================

-- Top products by gross sales revenue
SELECT
    stock_code,
    description,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT invoice) AS orders,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
GROUP BY
    stock_code,
    description
ORDER BY gross_sales_revenue DESC
LIMIT 20;
-- Investigate "Manual" transactions
SELECT
    invoice,
    invoice_date,
    customer_id,
    country,
    quantity,
    price,
    revenue
FROM clean_sales
WHERE stock_code = 'M'
ORDER BY revenue DESC
LIMIT 50;
-- Investigation of stock_code = 'M' ("Manual"):
-- Manual records consistently use quantity = 1 with highly variable prices.
-- These appear to represent manually entered charges/values rather than standard merchandise SKUs.
-- Retained in clean_sales, but excluded from merchandise product analysis.
-- Identify stock codes that may represent non-merchandise transactions
SELECT
    stock_code,
    description,
    COUNT(*) AS row_count,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
WHERE stock_code !~ '^[0-9]+[A-Z]?$'
GROUP BY
    stock_code,
    description
ORDER BY gross_sales_revenue DESC;

-- Top merchandise products by gross sales revenue
-- Excludes known operational/accounting transaction codes
SELECT
    stock_code,
    description,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT invoice) AS orders,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
WHERE stock_code NOT IN (
    'M',
    'DOT',
    'POST',
    'AMAZONFEE',
    'C2',
    'B',
    'ADJUST',
    'ADJUST2',
    'BANK CHARGES',
    'D',
    'TEST001'
)
GROUP BY
    stock_code,
    description
ORDER BY gross_sales_revenue DESC
LIMIT 20;
-- Top merchandise products by gross sales revenue
SELECT
    stock_code,
    description,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT invoice) AS orders,
    ROUND(
        SUM(quantity)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_units_per_order,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
WHERE stock_code NOT IN (
    'M',
    'DOT',
    'POST',
    'AMAZONFEE',
    'C2',
    'B',
    'ADJUST',
    'ADJUST2',
    'BANK CHARGES',
    'D',
    'TEST001'
)
GROUP BY
    stock_code,
    description
ORDER BY gross_sales_revenue DESC
LIMIT 20;

-- =====================================================
-- PRODUCT DEMAND
-- =====================================================

-- Products with the strongest recurring demand
SELECT
    stock_code,
    description,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units_sold,
    ROUND(
        SUM(quantity)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_units_per_order,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
WHERE stock_code NOT IN (
    'M',
    'DOT',
    'POST',
    'AMAZONFEE',
    'C2',
    'B',
    'ADJUST',
    'ADJUST2',
    'BANK CHARGES',
    'D',
    'TEST001'
)
GROUP BY
    stock_code,
    description
ORDER BY orders DESC
LIMIT 20;

-- =====================================================
-- PRODUCT PERFORMANCE COMPARISON
-- =====================================================

WITH product_performance AS (
    SELECT
        stock_code,
        description,
        COUNT(DISTINCT invoice) AS orders,
        SUM(quantity) AS units_sold,
        ROUND(
            SUM(quantity)::numeric
            / COUNT(DISTINCT invoice),
            2
        ) AS avg_units_per_order,
        ROUND(SUM(revenue), 2) AS gross_sales_revenue
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
    GROUP BY
        stock_code,
        description
),

ranked_products AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY gross_sales_revenue DESC
        ) AS revenue_rank,

        DENSE_RANK() OVER (
            ORDER BY orders DESC
        ) AS order_frequency_rank,

        DENSE_RANK() OVER (
            ORDER BY units_sold DESC
        ) AS units_sold_rank
    FROM product_performance
)

SELECT
    stock_code,
    description,
    orders,
    units_sold,
    avg_units_per_order,
    gross_sales_revenue,
    revenue_rank,
    order_frequency_rank,
    units_sold_rank
FROM ranked_products
ORDER BY revenue_rank
LIMIT 30;
-- Revenue concentration across merchandise products
WITH product_revenue AS (
    SELECT
        stock_code,
        description,
        SUM(revenue) AS gross_sales_revenue
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
    GROUP BY
        stock_code,
        description
),

ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY gross_sales_revenue DESC
        ) AS revenue_rank,
        SUM(gross_sales_revenue) OVER () AS total_revenue
    FROM product_revenue
)

SELECT
    ROUND(
        100.0 * SUM(gross_sales_revenue)
        FILTER (WHERE revenue_rank <= 10)
        / MAX(total_revenue),
        2
    ) AS top_10_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
        FILTER (WHERE revenue_rank <= 25)
        / MAX(total_revenue),
        2
    ) AS top_25_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
        FILTER (WHERE revenue_rank <= 50)
        / MAX(total_revenue),
        2
    ) AS top_50_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
        FILTER (WHERE revenue_rank <= 100)
        / MAX(total_revenue),
        2
    ) AS top_100_pct

FROM ranked_products;
-- Compare broad demand vs bulk-driven product performance
SELECT
    stock_code,
    description,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units_sold,
    ROUND(
        SUM(quantity)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_units_per_order,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue
FROM clean_sales
WHERE stock_code NOT IN (
    'M',
    'DOT',
    'POST',
    'AMAZONFEE',
    'C2',
    'B',
    'ADJUST',
    'ADJUST2',
    'BANK CHARGES',
    'D',
    'TEST001'
)
GROUP BY
    stock_code,
    description
HAVING COUNT(DISTINCT invoice) >= 10
ORDER BY avg_units_per_order DESC
LIMIT 30;
-- ============================================================
-- CUSTOMER ANALYSIS
-- ============================================================

-- Customer-level performance
WITH customer_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice) AS orders,
        SUM(quantity) AS units_purchased,
        ROUND(
            SUM(quantity)::numeric
            / COUNT(DISTINCT invoice),
            2
        ) AS avg_units_per_order,
        ROUND(SUM(revenue), 2) AS gross_sales_revenue,
        ROUND(
            SUM(revenue)::numeric
            / COUNT(DISTINCT invoice),
            2
        ) AS avg_order_value,
        MIN(invoice_date) AS first_purchase,
        MAX(invoice_date) AS last_purchase,
        COUNT(DISTINCT stock_code) AS unique_products
    FROM clean_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)

SELECT *
FROM customer_metrics
ORDER BY gross_sales_revenue DESC
LIMIT 30;
-- Investigate missing / blank customer IDs
SELECT
    CASE
        WHEN customer_id IS NULL THEN 'NULL'
        WHEN TRIM(customer_id) = '' THEN 'BLANK'
        ELSE 'VALID'
    END AS customer_id_status,
    COUNT(*) AS transaction_lines,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units_purchased,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue,
    COUNT(DISTINCT stock_code) AS unique_products
FROM clean_sales
GROUP BY
    CASE
        WHEN customer_id IS NULL THEN 'NULL'
        WHEN TRIM(customer_id) = '' THEN 'BLANK'
        ELSE 'VALID'
    END
ORDER BY gross_sales_revenue DESC;
-- Inspect transactions without a usable customer ID
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
WHERE customer_id IS NULL
   OR TRIM(customer_id) = ''
ORDER BY invoice_date
LIMIT 100;
-- ============================================================
-- CUSTOMER PERFORMANCE
-- ============================================================

-- Customer-level performance
WITH customer_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice) AS orders,
        SUM(quantity) AS units_purchased,
        ROUND(
            SUM(quantity)::numeric
            / COUNT(DISTINCT invoice),
            2
        ) AS avg_units_per_order,
        ROUND(SUM(revenue), 2) AS gross_sales_revenue,
        ROUND(
            SUM(revenue)::numeric
            / COUNT(DISTINCT invoice),
            2
        ) AS avg_order_value,
        MIN(invoice_date) AS first_purchase,
        MAX(invoice_date) AS last_purchase,
        COUNT(DISTINCT stock_code) AS unique_products
    FROM clean_sales
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
    GROUP BY customer_id
)

SELECT
    customer_id,
    orders,
    units_purchased,
    avg_units_per_order,
    gross_sales_revenue,
    avg_order_value,
    first_purchase,
    last_purchase,
    unique_products
FROM customer_metrics
ORDER BY gross_sales_revenue DESC
LIMIT 30;
-- Investigate customer 16446's unusually concentrated purchases
SELECT
    invoice,
    invoice_date,
    stock_code,
    description,
    quantity,
    price,
    revenue,
    country
FROM clean_sales
WHERE customer_id = '16446'
ORDER BY invoice_date, invoice, quantity DESC;
-- Product concentration for customer 16446
SELECT
    stock_code,
    description,
    COUNT(DISTINCT invoice) AS orders,
    SUM(quantity) AS units_purchased,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue,
    ROUND(
        SUM(revenue)::numeric / SUM(quantity),
        2
    ) AS avg_price_per_unit
FROM clean_sales
WHERE customer_id = '16446'
GROUP BY
    stock_code,
    description
ORDER BY gross_sales_revenue DESC;
-- Customer 16446 is a major bulk-order outlier:
-- 80,995 units of stock_code 23843 (PAPER CRAFT, LITTLE BIRDIE) purchased in a single transaction for £168,469.60.
-- This single order drives nearly all of the customer's lifetime revenue and materially affects product-level revenue/volume rankings.

-- Customer revenue concentration
WITH customer_revenue AS (
    SELECT
        customer_id,
        SUM(revenue) AS gross_sales_revenue
    FROM clean_sales
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
    GROUP BY customer_id
),

ranked_customers AS (
    SELECT
        customer_id,
        gross_sales_revenue,
        ROW_NUMBER() OVER (
            ORDER BY gross_sales_revenue DESC
        ) AS revenue_rank,
        SUM(gross_sales_revenue) OVER () AS total_customer_revenue
    FROM customer_revenue
)

SELECT
    ROUND(
        100.0 * SUM(gross_sales_revenue)
            FILTER (WHERE revenue_rank <= 10)
        / MAX(total_customer_revenue),
        2
    ) AS top_10_customer_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
            FILTER (WHERE revenue_rank <= 25)
        / MAX(total_customer_revenue),
        2
    ) AS top_25_customer_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
            FILTER (WHERE revenue_rank <= 50)
        / MAX(total_customer_revenue),
        2
    ) AS top_50_customer_pct,

    ROUND(
        100.0 * SUM(gross_sales_revenue)
            FILTER (WHERE revenue_rank <= 100)
        / MAX(total_customer_revenue),
        2
    ) AS top_100_customer_pct

FROM ranked_customers;

-- NOTE FOR R ANALYSIS:
-- Customer revenue shows moderate concentration:
-- Top 10 customers  = 16.04%
-- Top 25 customers  = 23.82%
-- Top 50 customers  = 30.33%
-- Top 100 customers = 37.55%
--
-- Further analysis in R:
--   * Lorenz curve for customer revenue
--   * Gini coefficient
--   * Revenue distribution / log-scale visualization
--   * Compare concentration of revenue vs orders vs units purchased

-- ============================================================
-- GEOGRAPHIC PERFORMANCE
-- ============================================================

-- Country-level sales performance
SELECT
    country,
    COUNT(DISTINCT invoice) AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(quantity) AS units_sold,
    ROUND(
        SUM(quantity)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_units_per_order,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue,
    ROUND(
        SUM(revenue)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_order_value
FROM clean_sales
GROUP BY country
ORDER BY gross_sales_revenue DESC;
-- ============================================================
-- TEMPORAL / SEASONALITY ANALYSIS
-- ============================================================

-- Monthly sales performance
SELECT
    DATE_TRUNC('month', invoice_date) AS month,
    COUNT(DISTINCT invoice) AS orders,
    COUNT(DISTINCT customer_id) FILTER (
        WHERE customer_id IS NOT NULL
          AND TRIM(customer_id) <> ''
    ) AS customers,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue), 2) AS gross_sales_revenue,
    ROUND(
        SUM(revenue)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_order_value,
    ROUND(
        SUM(quantity)::numeric
        / COUNT(DISTINCT invoice),
        2
    ) AS avg_units_per_order
FROM clean_sales
GROUP BY DATE_TRUNC('month', invoice_date)
ORDER BY month;
-- ============================================================
-- MONTH-OVER-MONTH PERFORMANCE
-- ============================================================

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', invoice_date) AS month,
        COUNT(DISTINCT invoice) AS orders,
        COUNT(DISTINCT customer_id) FILTER (
            WHERE customer_id IS NOT NULL
              AND TRIM(customer_id) <> ''
        ) AS customers,
        SUM(quantity) AS units_sold,
        ROUND(SUM(revenue), 2) AS gross_sales_revenue
    FROM clean_sales
    GROUP BY DATE_TRUNC('month', invoice_date)
),

monthly_growth AS (
    SELECT
        month,
        orders,
        customers,
        units_sold,
        gross_sales_revenue,

        LAG(orders) OVER (ORDER BY month) AS previous_orders,
        LAG(units_sold) OVER (ORDER BY month) AS previous_units,
        LAG(gross_sales_revenue) OVER (ORDER BY month) AS previous_revenue

    FROM monthly_sales
)

SELECT
    month,
    orders,
    ROUND(
        100.0 * (orders - previous_orders)
        / NULLIF(previous_orders, 0),
        2
    ) AS order_growth_pct,

    units_sold,
    ROUND(
        100.0 * (units_sold - previous_units)
        / NULLIF(previous_units, 0),
        2
    ) AS unit_growth_pct,

    gross_sales_revenue,
    ROUND(
        100.0 * (gross_sales_revenue - previous_revenue)
        / NULLIF(previous_revenue, 0),
        2
    ) AS revenue_growth_pct

FROM monthly_growth
ORDER BY month;

--ignore the December 2011 −57.59% figure as a growth signal, because the dataset ends December 9. 
--That isn't a business collapse; it's an incomplete month. December 2010's −43.9% is more interesting because it's a complete month and could indicate the holiday peak occurs before December for this business.

-- ============================================================
-- YEAR-OVER-YEAR MONTHLY PERFORMANCE
-- Compare each month in 2011 with the same month in 2010
-- ============================================================

WITH monthly_sales AS (
    SELECT
        EXTRACT(YEAR FROM invoice_date)::int AS year,
        EXTRACT(MONTH FROM invoice_date)::int AS month_num,
        COUNT(DISTINCT invoice) AS orders,
        COUNT(DISTINCT customer_id) FILTER (
            WHERE customer_id IS NOT NULL
              AND TRIM(customer_id) <> ''
        ) AS customers,
        SUM(quantity) AS units_sold,
        SUM(revenue) AS gross_sales_revenue
    FROM clean_sales
    GROUP BY
        EXTRACT(YEAR FROM invoice_date),
        EXTRACT(MONTH FROM invoice_date)
),

yoy AS (
    SELECT
        *,
        LAG(orders) OVER (
            PARTITION BY month_num
            ORDER BY year
        ) AS previous_year_orders,

        LAG(customers) OVER (
            PARTITION BY month_num
            ORDER BY year
        ) AS previous_year_customers,

        LAG(units_sold) OVER (
            PARTITION BY month_num
            ORDER BY year
        ) AS previous_year_units,

        LAG(gross_sales_revenue) OVER (
            PARTITION BY month_num
            ORDER BY year
        ) AS previous_year_revenue

    FROM monthly_sales
)

SELECT
    year,
    month_num,

    orders,
    ROUND(
        100.0 * (orders - previous_year_orders)
        / NULLIF(previous_year_orders, 0),
        2
    ) AS order_yoy_growth_pct,

    customers,
    ROUND(
        100.0 * (customers - previous_year_customers)
        / NULLIF(previous_year_customers, 0),
        2
    ) AS customer_yoy_growth_pct,

    units_sold,
    ROUND(
        100.0 * (units_sold - previous_year_units)
        / NULLIF(previous_year_units, 0),
        2
    ) AS unit_yoy_growth_pct,

    ROUND(gross_sales_revenue, 2) AS gross_sales_revenue,
    ROUND(
        100.0 * (gross_sales_revenue - previous_year_revenue)
        / NULLIF(previous_year_revenue, 0),
        2
    ) AS revenue_yoy_growth_pct

FROM yoy

-- Only show periods where a prior-year comparison exists
WHERE previous_year_revenue IS NOT NULL

-- December 2011 is incomplete, so exclude it
AND NOT (year = 2011 AND month_num = 12)

ORDER BY year, month_num;

-- ============================================================
-- COUNTRY REVENUE CONCENTRATION
-- ============================================================

WITH country_sales AS (
    SELECT
        country,
        COUNT(DISTINCT invoice) AS orders,
        SUM(quantity) AS units_sold,
        SUM(revenue) AS gross_sales_revenue
    FROM clean_sales
    GROUP BY country
),

total_sales AS (
    SELECT
        SUM(gross_sales_revenue) AS total_revenue
    FROM country_sales
)

SELECT
    country,
    orders,
    units_sold,
    ROUND(gross_sales_revenue, 2) AS gross_sales_revenue,
    ROUND(
        100.0 * gross_sales_revenue
        / total_revenue,
        2
    ) AS revenue_share_pct
FROM country_sales
CROSS JOIN total_sales
ORDER BY gross_sales_revenue DESC;

-- ============================================================
-- PRODUCT DEFINITION CONSISTENCY
-- Quantify stock codes associated with multiple descriptions
-- ============================================================

WITH product_descriptions AS (
    SELECT
        stock_code,
        COUNT(DISTINCT description) AS description_count,
        COUNT(*) AS transaction_lines
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
    GROUP BY stock_code
)

SELECT
    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE description_count > 1
    ) AS products_multiple_descriptions,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE description_count > 1)
        / COUNT(*),
        2
    ) AS pct_multiple_descriptions,

    MAX(description_count) AS max_descriptions_per_product

FROM product_descriptions;

-- ============================================================
-- PRICE CONSISTENCY BY PRODUCT
-- Measure within-product price variation
-- ============================================================

WITH product_prices AS (
    SELECT
        stock_code,
        COUNT(DISTINCT description) AS description_count,
        COUNT(*) AS transaction_lines,
        MIN(price) AS min_price,
        MAX(price) AS max_price,
        AVG(price) AS avg_price,
        STDDEV(price) AS price_sd
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
      AND price > 0
    GROUP BY stock_code
),

price_variation AS (
    SELECT
        *,
        ROUND(
            100.0 * price_sd / NULLIF(avg_price, 0),
            2
        ) AS price_cv_pct,

        max_price / NULLIF(min_price, 0) AS max_min_price_ratio
    FROM product_prices
)

SELECT
    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE description_count > 1
    ) AS multiple_description_products,

    COUNT(*) FILTER (
        WHERE max_min_price_ratio >= 2
    ) AS price_ratio_2x,

    COUNT(*) FILTER (
        WHERE max_min_price_ratio >= 5
    ) AS price_ratio_5x,

    COUNT(*) FILTER (
        WHERE max_min_price_ratio >= 10
    ) AS price_ratio_10x,

    COUNT(*) FILTER (
        WHERE max_min_price_ratio >= 50
    ) AS price_ratio_50x,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE max_min_price_ratio >= 10)
        / COUNT(*),
        2
    ) AS pct_products_price_ratio_10x

FROM price_variation;

-- ============================================================
-- MOST EXTREME PRODUCT PRICE VARIATION
-- Excludes known non-merchandise codes
-- ============================================================

SELECT
    stock_code,
    COUNT(DISTINCT description) AS description_count,
    COUNT(*) AS transaction_lines,
    ROUND(MIN(price), 2) AS min_price,
    ROUND(MAX(price), 2) AS max_price,

    ROUND(
        MAX(price) / NULLIF(MIN(price), 0),
        2
    ) AS max_min_price_ratio

FROM clean_sales

WHERE stock_code NOT IN (
    'M',
    'DOT',
    'POST',
    'AMAZONFEE',
    'C2',
    'B',
    'ADJUST',
    'ADJUST2',
    'BANK CHARGES',
    'D',
    'TEST001'
)

AND price > 0

GROUP BY stock_code

HAVING COUNT(*) >= 10

ORDER BY max_min_price_ratio DESC

LIMIT 50;

-- ============================================================
-- INVESTIGATE EXTREME WITHIN-PRODUCT PRICE VARIATION
-- Show transactions at each product's maximum observed price
-- ============================================================

WITH product_price_range AS (
    SELECT
        stock_code,
        MIN(price) AS min_price,
        MAX(price) AS max_price,
        MAX(price) / NULLIF(MIN(price), 0) AS price_ratio
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
      AND price > 0
    GROUP BY stock_code
),

extreme_products AS (
    SELECT *
    FROM product_price_range
    WHERE price_ratio >= 50
)

SELECT
    c.invoice,
    c.invoice_date,
    c.stock_code,
    c.description,
    c.quantity,
    c.price,
    c.revenue,
    c.customer_id,
    c.country,
    ROUND(e.min_price, 2) AS product_min_price,
    ROUND(e.max_price, 2) AS product_max_price,
    ROUND(e.price_ratio, 2) AS price_ratio
FROM clean_sales c

JOIN extreme_products e
    ON c.stock_code = e.stock_code

WHERE c.price = e.max_price

ORDER BY e.price_ratio DESC, c.invoice_date;

-- ============================================================
-- INVESTIGATE EXTREME LOW PRICES
-- Compare each transaction price with its product median price
-- ============================================================

WITH product_price_stats AS (
    SELECT
        stock_code,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY price) AS median_price
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
      AND price > 0
    GROUP BY stock_code
),

flagged_transactions AS (
    SELECT
        c.invoice,
        c.invoice_date,
        c.stock_code,
        c.description,
        c.quantity,
        c.price,
        p.median_price,
        c.price / NULLIF(p.median_price, 0) AS price_to_median_ratio,
        c.revenue,
        c.customer_id,
        c.country
    FROM clean_sales c
    JOIN product_price_stats p
        ON c.stock_code = p.stock_code
    WHERE c.price > 0
      AND c.price <= p.median_price * 0.20
)

SELECT
    stock_code,
    description,
    COUNT(*) AS extreme_low_price_lines,
    COUNT(DISTINCT invoice) AS extreme_low_price_orders,
    MIN(price) AS min_price,
    ROUND(median_price::numeric, 2) AS median_price,
    SUM(quantity) AS units_sold_at_extreme_low_price,
    MIN(invoice_date) AS first_low_price_date,
    MAX(invoice_date) AS last_low_price_date
FROM flagged_transactions
GROUP BY
    stock_code,
    description,
    median_price
ORDER BY extreme_low_price_lines DESC
LIMIT 50;

-- ============================================================
-- LOW PRICE VS NORMAL PRICE DEMAND
-- Compare quantities within the same product
-- ============================================================

WITH product_price_stats AS (
    SELECT
        stock_code,
        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY price) AS median_price
    FROM clean_sales
    WHERE stock_code NOT IN (
        'M',
        'DOT',
        'POST',
        'AMAZONFEE',
        'C2',
        'B',
        'ADJUST',
        'ADJUST2',
        'BANK CHARGES',
        'D',
        'TEST001'
    )
      AND price > 0
    GROUP BY stock_code
),

classified_sales AS (
    SELECT
        c.stock_code,
        c.description,
        c.quantity,
        c.price,
        p.median_price,

        CASE
            WHEN c.price <= p.median_price * 0.20
                THEN 'EXTREME LOW'
            ELSE 'NORMAL'
        END AS price_group

    FROM clean_sales c

    JOIN product_price_stats p
        ON c.stock_code = p.stock_code

    WHERE c.price > 0
)

SELECT
    stock_code,
    MAX(description) AS description,
    ROUND(MAX(median_price)::numeric, 2) AS median_price,

    COUNT(*) FILTER (
        WHERE price_group = 'EXTREME LOW'
    ) AS low_price_lines,

    ROUND(
        AVG(quantity) FILTER (
            WHERE price_group = 'EXTREME LOW'
        ),
        2
    ) AS avg_qty_low_price,

    COUNT(*) FILTER (
        WHERE price_group = 'NORMAL'
    ) AS normal_price_lines,

    ROUND(
        AVG(quantity) FILTER (
            WHERE price_group = 'NORMAL'
        ),
        2
    ) AS avg_qty_normal_price,

    ROUND(
        AVG(quantity) FILTER (
            WHERE price_group = 'EXTREME LOW'
        )
        /
        NULLIF(
            AVG(quantity) FILTER (
                WHERE price_group = 'NORMAL'
            ),
            0
        ),
        2
    ) AS quantity_ratio

FROM classified_sales

GROUP BY stock_code

HAVING COUNT(*) FILTER (
    WHERE price_group = 'EXTREME LOW'
) >= 5

ORDER BY quantity_ratio DESC;