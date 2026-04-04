/**************************************************************
 * MySQL 8.0: Indexing Bad Practices and Optimal Approaches
 * This script demonstrates 10 common indexing bad
 * practices in MySQL and provides the correct (optimal)
 * approach for each scenario.  Adjust table and index
 * names to match your own workload and query patterns.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

-------------------------------------------------
-- Region: 1. Over-Indexing vs. Optimal Composite Indexes
-------------------------------------------------
/*
  BAD PRACTICE:
    Creating separate single-column indexes on every filtered column
    adds unnecessary write-overhead and wastes buffer-pool pages.

  CORRECT APPROACH:
    Analyse query patterns and build one composite (covering) index
    that satisfies the most common WHERE, ORDER BY, and SELECT
    requirements at once.
*/
DROP TABLE IF EXISTS orders;

CREATE TABLE orders
(
    order_id    INT           PRIMARY KEY AUTO_INCREMENT,
    customer_id INT           NOT NULL,
    order_date  DATE          NOT NULL,
    status      VARCHAR(20)   NOT NULL,
    amount      DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

-- BAD: four separate single-column indexes
CREATE INDEX idx_orders_customer  ON orders (customer_id);
CREATE INDEX idx_orders_date      ON orders (order_date);
CREATE INDEX idx_orders_status    ON orders (status);
CREATE INDEX idx_orders_amount    ON orders (amount);

-- CORRECT: drop them and create one composite covering index
ALTER TABLE orders
    DROP INDEX idx_orders_customer,
    DROP INDEX idx_orders_date,
    DROP INDEX idx_orders_status,
    DROP INDEX idx_orders_amount;

-- Leading equality columns first, range column last, then INCLUDE columns
CREATE INDEX idx_orders_composite
    ON orders (customer_id, order_date)
    COMMENT 'covering: status and amount in the leaf';
-- MySQL does not have INCLUDE; add status/amount to the key if queries need them:
-- CREATE INDEX idx_orders_composite ON orders (customer_id, order_date, status, amount);

-------------------------------------------------
-- Region: 2. Indexing Frequently Updated Columns
-------------------------------------------------
/*
  BAD PRACTICE:
    Indexing a column that is updated with every login adds write overhead
    and cache churn without meaningfully helping SELECT queries.

  CORRECT APPROACH:
    Avoid indexing volatile columns unless profiling proves a query
    benefit that outweighs a maintenance cost.
*/
DROP TABLE IF EXISTS user_accounts;

CREATE TABLE user_accounts
(
    user_id       INT         PRIMARY KEY AUTO_INCREMENT,
    username      VARCHAR(60) NOT NULL UNIQUE,
    last_login_at DATETIME
) ENGINE = InnoDB;

-- BAD: index on a column updated every session
CREATE INDEX idx_users_last_login ON user_accounts (last_login_at);

-- CORRECT: drop it; use the primary key or username index for lookups
ALTER TABLE user_accounts DROP INDEX idx_users_last_login;

-------------------------------------------------
-- Region: 3. Missing INCLUDE Equivalent – Covering Indexes
-------------------------------------------------
/*
  BAD PRACTICE:
    An index that covers only the WHERE column forces InnoDB to do a
    secondary-index lookup (bookmark lookup) for every matched row.

  CORRECT APPROACH:
    Add the SELECT columns to the index key to make it covering.
    MySQL does not have a separate INCLUDE clause; just extend the key.
*/
DROP TABLE IF EXISTS products;

CREATE TABLE products
(
    product_id   INT          PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(200) NOT NULL,
    category_id  INT          NOT NULL,
    price        DECIMAL(10,2) NOT NULL,
    stock        INT
) ENGINE = InnoDB;

-- BAD: only category_id; product_name and price require a row lookup
CREATE INDEX idx_products_category_bad ON products (category_id);

-- CORRECT: include product_name and price in the key
ALTER TABLE products DROP INDEX idx_products_category_bad;
CREATE INDEX idx_products_category_covering
    ON products (category_id, product_name, price);

-- Verify coverage with EXPLAIN (Extra: "Using index")
EXPLAIN
SELECT product_name, price
FROM products
WHERE category_id = 5;

-------------------------------------------------
-- Region: 4. Wrong Column Order in Composite Indexes
-------------------------------------------------
/*
  BAD PRACTICE:
    Placing a range column before an equality column in a composite
    index means the equality column cannot benefit from the index at all
    for range queries.

  CORRECT APPROACH:
    Equality predicates first, range predicates last.
*/
DROP TABLE IF EXISTS sales;

CREATE TABLE sales
(
    sale_id   INT IDENTITY PRIMARY KEY AUTO_INCREMENT,
    region_id INT  NOT NULL,
    sale_date DATE NOT NULL,
    total     DECIMAL(10,2)
) ENGINE = InnoDB;

-- BAD: range column (sale_date) before equality column (region_id)
CREATE INDEX idx_sales_bad  ON sales (sale_date, region_id);

-- CORRECT: equality first, range second
ALTER TABLE sales DROP INDEX idx_sales_bad;
CREATE INDEX idx_sales_good ON sales (region_id, sale_date);

EXPLAIN
SELECT sale_id, total
FROM sales
WHERE region_id = 3
  AND sale_date >= '2024-01-01';

-------------------------------------------------
-- Region: 5. Implicit NULL Handling in Indexes
-------------------------------------------------
/*
  BAD PRACTICE:
    Assuming NULL values are excluded from an index.  InnoDB does index
    NULL values; however, IS NULL predicates on nullable columns may
    still force full scans in older optimiser versions.

  CORRECT APPROACH:
    Use NOT NULL + DEFAULT on columns used as index keys wherever
    possible.  If NULL is needed, test with EXPLAIN to confirm index use.
*/
DROP TABLE IF EXISTS events_log;

CREATE TABLE events_log
(
    event_id   INT  PRIMARY KEY AUTO_INCREMENT,
    event_type VARCHAR(30),          -- nullable (BAD design for an indexed column)
    event_at   DATETIME NOT NULL
) ENGINE = InnoDB;

-- BAD: nullable column in an index
CREATE INDEX idx_events_type_bad ON events_log (event_type);

-- CORRECT: make the column NOT NULL with a default sentinel value
ALTER TABLE events_log
    MODIFY COLUMN event_type VARCHAR(30) NOT NULL DEFAULT 'unknown';

-- The existing index is now more effective
EXPLAIN SELECT event_id FROM events_log WHERE event_type = 'login';

-------------------------------------------------
-- Region: 6. Creating Indexes Before Bulk Load
-------------------------------------------------
/*
  BAD PRACTICE:
    Leaving all secondary indexes in place during a large INSERT batch;
    InnoDB must update every index for every inserted row.

  CORRECT APPROACH:
    Disable non-unique index maintenance, load the data, then re-enable.
    For MyISAM this is DISABLE KEYS / ENABLE KEYS; for InnoDB the
    equivalent is to drop secondary indexes, load, then recreate them.
*/
DROP TABLE IF EXISTS bulk_load_demo;

CREATE TABLE bulk_load_demo
(
    id       INT          PRIMARY KEY AUTO_INCREMENT,
    code     VARCHAR(20)  NOT NULL,
    payload  TEXT,
    INDEX idx_code (code)
) ENGINE = InnoDB;

-- CORRECT pattern: drop secondary index, bulk load, recreate
ALTER TABLE bulk_load_demo DROP INDEX idx_code;

-- ... bulk INSERT here ...
INSERT INTO bulk_load_demo (code, payload)
VALUES ('A001','data'),('A002','data'),('A003','data');

ALTER TABLE bulk_load_demo ADD INDEX idx_code (code);

-------------------------------------------------
-- Region: 7. Using Functions on Indexed Columns (Non-SARGable)
-------------------------------------------------
/*
  BAD PRACTICE:
    Wrapping an indexed column inside a function in the WHERE clause
    disables index access; MySQL must evaluate the function for every row.

  CORRECT APPROACH:
    Re-write the predicate to compare the column directly, or create a
    functional index (MySQL 8.0+).
*/
DROP TABLE IF EXISTS date_orders;

CREATE TABLE date_orders
(
    order_id   INT  PRIMARY KEY AUTO_INCREMENT,
    order_date DATE NOT NULL,
    amount     DECIMAL(10,2),
    INDEX idx_order_date (order_date)
) ENGINE = InnoDB;

-- BAD: YEAR() prevents index access
-- EXPLAIN SELECT * FROM date_orders WHERE YEAR(order_date) = 2024;

-- CORRECT: use a range predicate
EXPLAIN
SELECT * FROM date_orders
WHERE order_date >= '2024-01-01'
  AND order_date <  '2025-01-01';

-- CORRECT (alternative): functional index (MySQL 8.0+)
ALTER TABLE date_orders ADD INDEX idx_order_year ((YEAR(order_date)));

EXPLAIN
SELECT * FROM date_orders WHERE YEAR(order_date) = 2024;

-------------------------------------------------
-- Region: 8. Excessive Index Count per Table
-------------------------------------------------
/*
  BAD PRACTICE:
    Adding an index for every column "just in case" multiplies write
    amplification, increases buffer-pool pressure, and confuses the
    optimizer with too many choices.

  CORRECT APPROACH:
    Audit index usage with performance_schema and sys schema views.
    Remove any index that is never chosen by the optimizer.
*/
-- Identify unused indexes in the current database
SELECT
    object_schema,
    object_name  AS table_name,
    index_name,
    last_accessed
FROM sys.schema_unused_indexes
WHERE object_schema = DATABASE();

-------------------------------------------------
-- Region: 9. Ignoring Descending Indexes
-------------------------------------------------
/*
  BAD PRACTICE:
    Relying on a forward-scan index for ORDER BY … DESC queries causes
    the optimizer to read index pages backward, which can be slower for
    large result sets.

  CORRECT APPROACH:
    Create a descending index on columns that are consistently sorted
    in descending order (MySQL 8.0 supports DESC in index definitions).
*/
DROP TABLE IF EXISTS timeseries;

CREATE TABLE timeseries
(
    ts_id      INT      PRIMARY KEY AUTO_INCREMENT,
    recorded_at DATETIME NOT NULL,
    value       DECIMAL(12,4)
) ENGINE = InnoDB;

-- CORRECT: explicit DESC index for "latest N rows" queries
CREATE INDEX idx_timeseries_recorded_desc ON timeseries (recorded_at DESC);

EXPLAIN
SELECT ts_id, value
FROM timeseries
ORDER BY recorded_at DESC
LIMIT 10;

-------------------------------------------------
-- Region: 10. Not Using Invisible Indexes for Safe Removal Testing
-------------------------------------------------
/*
  BAD PRACTICE:
    Dropping an index immediately without testing whether it is truly
    unused – a subsequent workload change might require it.

  CORRECT APPROACH:
    Mark the index INVISIBLE first, monitor the workload, then drop
    only after confirming no regression.
*/
-- Mark invisible
ALTER TABLE products ALTER INDEX idx_products_category_covering INVISIBLE;

-- Check that the query plan is unchanged under forced invisible usage
SET SESSION optimizer_switch = 'use_invisible_indexes=on';
EXPLAIN SELECT product_name, price FROM products WHERE category_id = 1;
SET SESSION optimizer_switch = 'use_invisible_indexes=off';

-- Restore visibility if a regression is observed; otherwise drop:
ALTER TABLE products ALTER INDEX idx_products_category_covering VISIBLE;
-- ALTER TABLE products DROP INDEX idx_products_category_covering;

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS timeseries;
DROP TABLE IF EXISTS bulk_load_demo;
DROP TABLE IF EXISTS events_log;
DROP TABLE IF EXISTS date_orders;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS user_accounts;
DROP TABLE IF EXISTS orders;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
