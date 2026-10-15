-- ============================================================
-- Retail Pricing Analysis
-- 03_data_cleaning.sql
--
-- Purpose:
-- Create an analysis-ready sales dataset from raw_transactions.
-- The raw source table is preserved unchanged.
-- ============================================================


-- Preview records meeting the primary sales criteria
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
-- Measure the effect of primary sales filters
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
-- Identify duplicate rows within the primary sales dataset
WITH ranked_sales AS (
    SELECT
        invoice,
        stock_code,
        description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country,
        quantity * price AS revenue,

        ROW_NUMBER() OVER (
            PARTITION BY
                invoice,
                stock_code,
                description,
                quantity,
                invoice_date,
                price,
                customer_id,
                country
            ORDER BY invoice
        ) AS duplicate_rank

    FROM raw_transactions
    WHERE quantity > 0
      AND price > 0
      AND invoice NOT LIKE 'C%'
)

SELECT *
FROM ranked_sales
WHERE duplicate_rank > 1
ORDER BY invoice, stock_code
LIMIT 30;
-- Count excess duplicates remaining after primary sales filters
WITH ranked_sales AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY
                invoice,
                stock_code,
                description,
                quantity,
                invoice_date,
                price,
                customer_id,
                country
            ORDER BY invoice
        ) AS duplicate_rank

    FROM raw_transactions
    WHERE quantity > 0
      AND price > 0
      AND invoice NOT LIKE 'C%'
)

SELECT
    COUNT(*) AS excess_duplicates_in_sales
FROM ranked_sales
WHERE duplicate_rank > 1;
-- ============================================================
-- CLEAN SALES TABLE
-- ============================================================
-- Keeps valid positive-price, positive-quantity sales
-- removes exact duplicate transaction lines.
-- raw_transactions remains unchanged.

DROP TABLE IF EXISTS clean_sales;

CREATE TABLE clean_sales AS

WITH ranked_sales AS (
    SELECT
        invoice,
        stock_code,
        description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country,

        ROW_NUMBER() OVER (
            PARTITION BY
                invoice,
                stock_code,
                description,
                quantity,
                invoice_date,
                price,
                customer_id,
                country
            ORDER BY invoice
        ) AS duplicate_rank

    FROM raw_transactions

    WHERE quantity > 0
      AND price > 0
      AND invoice NOT LIKE 'C%'
)

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

FROM ranked_sales

WHERE duplicate_rank = 1;
-- Verify final table
SELECT COUNT(*) AS clean_rows
FROM clean_sales;
SELECT
    MIN(invoice_date) AS first_transaction,
    MAX(invoice_date) AS last_transaction,
    COUNT(DISTINCT invoice) AS unique_invoices,
    COUNT(DISTINCT stock_code) AS unique_products,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(revenue) AS gross_sales_revenue
FROM clean_sales;