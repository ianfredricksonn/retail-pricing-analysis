-- =====================================================
-- 02 DATA QUALITY
-- =====================================================
-- Purpose:
-- Profile raw_transactions before cleaning.
-- Investigate missing values, returns/cancellations,
-- nonpositive prices, and exact duplicate rows.
-- =====================================================


-- =====================================================
-- 1. BASIC TABLE PROFILE
-- =====================================================

-- Total number of raw transaction rows
SELECT
    COUNT(*) AS total_rows
FROM raw_transactions;


-- Preview raw data
SELECT *
FROM raw_transactions
LIMIT 20;


-- Transaction date range
SELECT
    MIN(invoice_date) AS first_transaction,
    MAX(invoice_date) AS last_transaction
FROM raw_transactions;


-- Basic cardinality checks
SELECT
    COUNT(DISTINCT invoice) AS unique_invoices,
    COUNT(DISTINCT stock_code) AS unique_stock_codes,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT country) AS unique_countries
FROM raw_transactions;


-- =====================================================
-- 2. MISSING VALUES
-- =====================================================

-- Count NULL values across important columns
SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE invoice IS NULL
    ) AS missing_invoice,

    COUNT(*) FILTER (
        WHERE stock_code IS NULL
    ) AS missing_stock_code,

    COUNT(*) FILTER (
        WHERE description IS NULL
    ) AS missing_description,

    COUNT(*) FILTER (
        WHERE quantity IS NULL
    ) AS missing_quantity,

    COUNT(*) FILTER (
        WHERE invoice_date IS NULL
    ) AS missing_invoice_date,

    COUNT(*) FILTER (
        WHERE price IS NULL
    ) AS missing_price,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE country IS NULL
    ) AS missing_country

FROM raw_transactions;


-- Inspect records with missing descriptions
SELECT *
FROM raw_transactions
WHERE description IS NULL
LIMIT 30;


-- Inspect records with missing customer IDs
SELECT *
FROM raw_transactions
WHERE customer_id IS NULL
LIMIT 30;


-- =====================================================
-- 3. QUANTITY QUALITY CHECKS
-- =====================================================

-- Break down positive, zero, and negative quantities
SELECT
    COUNT(*) FILTER (
        WHERE quantity < 0
    ) AS negative_quantity_rows,

    COUNT(*) FILTER (
        WHERE quantity = 0
    ) AS zero_quantity_rows,

    COUNT(*) FILTER (
        WHERE quantity > 0
    ) AS positive_quantity_rows

FROM raw_transactions;


-- Inspect largest negative quantities
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country
FROM raw_transactions
WHERE quantity < 0
ORDER BY quantity
LIMIT 20;


-- Determine whether negative quantities correspond to cancellation invoices
SELECT
    COUNT(*) FILTER (
        WHERE quantity < 0
    ) AS negative_quantity_rows,

    COUNT(*) FILTER (
        WHERE quantity < 0
          AND invoice LIKE 'C%'
    ) AS negative_with_c_invoice,

    COUNT(*) FILTER (
        WHERE quantity < 0
          AND invoice NOT LIKE 'C%'
    ) AS negative_without_c_invoice

FROM raw_transactions;


-- Known result from profiling:
-- negative_quantity_rows     = 22,950
-- negative_with_c_invoice    = 19,493
-- negative_without_c_invoice = 3,457


-- Inspect negative quantities that are NOT
-- cancellation invoices
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country
FROM raw_transactions
WHERE quantity < 0
  AND invoice NOT LIKE 'C%'
ORDER BY quantity
LIMIT 30;


-- Most common descriptions among
-- non-cancellation negative quantities
SELECT
    description,
    COUNT(*) AS row_count,
    SUM(quantity) AS total_quantity
FROM raw_transactions
WHERE quantity < 0
  AND invoice NOT LIKE 'C%'
GROUP BY description
ORDER BY row_count DESC
LIMIT 20;


-- During profiling, common descriptions included:
-- NULL / blank descriptions
-- check
-- damages
-- damaged
-- missing
-- sold as set on dotcom
-- unsaleable/destroyed
-- throw away
-- smashed
-- given away
--
-- Interpretation:
-- Not all negative quantities represent customer returns.
-- Some appear to be inventory adjustments, damaged/missing
-- stock, write-offs, or other operational corrections.


-- =====================================================
-- 4. PRICE QUALITY CHECKS
-- =====================================================

-- Break down negative, zero, and positive prices
SELECT
    COUNT(*) FILTER (
        WHERE price < 0
    ) AS negative_price,

    COUNT(*) FILTER (
        WHERE price = 0
    ) AS zero_price,

    COUNT(*) FILTER (
        WHERE price > 0
    ) AS positive_price

FROM raw_transactions;


-- Known result from profiling:
-- negative_price = 5
-- zero_price     = 6,202
-- positive_price = 1,061,164


-- Inspect nonpositive-price records
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country
FROM raw_transactions
WHERE price <= 0
ORDER BY price, invoice_date
LIMIT 30;


-- Most common descriptions among nonpositive-price records
SELECT
    description,
    COUNT(*) AS row_count
FROM raw_transactions
WHERE price <= 0
GROUP BY description
ORDER BY row_count DESC
LIMIT 20;


-- Profiling showed many nonpositive-price records
-- associated with operational descriptions such as:
-- check
-- damages / damaged
-- missing
-- adjustments
-- dotcom-related records
--
-- These records are not appropriate for positive-sales
-- revenue analysis.


-- =====================================================
-- 5. EXACT DUPLICATE TRANSACTIONS
-- =====================================================

-- Identify exact duplicate transaction rows
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    COUNT(*) AS duplicate_count
FROM raw_transactions
GROUP BY
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 30;


-- duplicate_count tells us how many copies exist for
-- each duplicated transaction signature.
--
-- Example:
-- duplicate_count = 6 means that exact transaction
-- appears six times, producing five EXCESS duplicates.


-- Count total excess duplicate rows
WITH duplicate_groups AS (
    SELECT
        invoice,
        stock_code,
        description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country,
        COUNT(*) AS duplicate_count
    FROM raw_transactions
    GROUP BY
        invoice,
        stock_code,
        description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country
    HAVING COUNT(*) > 1
)
SELECT
    SUM(duplicate_count - 1) AS excess_duplicate_rows
FROM duplicate_groups;


-- Known result from raw-data profiling:
-- excess_duplicate_rows = 34,335
--
-- Important:
-- This is different from duplicate_count.
-- duplicate_count measures copies within ONE duplicate group.
-- excess_duplicate_rows measures how many rows could be
-- removed across ALL groups while retaining one copy.


-- =====================================================
-- 6. PRIMARY SALES FILTER PREVIEW
-- =====================================================

-- Preview rows that would qualify as positive sales
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    quantity * price AS revenue
FROM raw_transactions
WHERE quantity > 0
  AND price > 0
  AND invoice NOT LIKE 'C%'
LIMIT 20;


-- Measure effect of primary sales filters
SELECT
    COUNT(*) AS raw_rows,

    COUNT(*) FILTER (
        WHERE quantity > 0
    ) AS positive_quantity_rows,

    COUNT(*) FILTER (
        WHERE quantity > 0
          AND price > 0
    ) AS positive_quantity_price_rows,

    COUNT(*) FILTER (
        WHERE quantity > 0
          AND price > 0
          AND invoice NOT LIKE 'C%'
    ) AS primary_sales_rows

FROM raw_transactions;


-- Known results:
-- raw_rows                     = 1,067,371
-- positive_quantity_rows       = 1,044,421
-- positive_quantity_price_rows = 1,041,671
-- primary_sales_rows           = 1,041,670


-- =====================================================
-- DATA QUALITY SUMMARY
-- =====================================================

-- Findings:
--
-- 1. Negative quantities:
--    22,950 rows contained negative quantities.
--    19,493 were associated with invoice IDs beginning
--    with "C", consistent with cancellation/return records.
--    The remaining 3,457 included operational inventory
--    adjustments such as damages, missing stock, write-offs,
--    and other corrections.
--
-- 2. Nonpositive prices:
--    5 rows contained negative prices and 6,202 contained
--    zero prices. These records are excluded from positive
--    sales analysis.
--
-- 3. Duplicate records:
--    Exact duplicates were identified across all transaction
--    attributes. The raw dataset contained 34,335 excess
--    duplicate rows.
--
-- 4. Sales definition:
--    Primary sales analysis uses transactions satisfying:
--        quantity > 0
--        price > 0
--        invoice NOT LIKE 'C%'
--
-- 5. Cleaning strategy:
--    The raw_transactions table remains unchanged.
--    Cleaning and deduplication are performed separately
--    when constructing clean_sales.