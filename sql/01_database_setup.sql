SELECT
    current_database() AS database_name,
    current_user AS user_name;
CREATE TABLE raw_transactions (
    invoice TEXT,
    stock_code TEXT,
    description TEXT,
    quantity INTEGER,
    invoice_date TIMESTAMP,
    price NUMERIC,
    customer_id TEXT,
    country TEXT
);
/* ============================================================
   IMPORT VALIDATION
   ============================================================ */

-- Check total number of imported transaction lines
SELECT COUNT(*) AS total_rows
FROM raw_transactions;


-- Inspect sample records
SELECT *
FROM raw_transactions
LIMIT 10;


-- Check transaction date range
SELECT
    MIN(invoice_date) AS earliest_transaction,
    MAX(invoice_date) AS latest_transaction
FROM raw_transactions;


-- Check transaction-line counts by calendar year
SELECT
    EXTRACT(YEAR FROM invoice_date) AS year,
    COUNT(*) AS transaction_lines
FROM raw_transactions
GROUP BY EXTRACT(YEAR FROM invoice_date)
ORDER BY year;