/**************************************************************
 * MySQL 8.0 Index Utilities – Part 1
 * This script demonstrates practical index analysis
 * using MySQL system views and the performance_schema.
 * It covers:
 * - Listing all indexes on a database or table.
 * - Identifying unused and duplicate indexes.
 * - Checking missing index candidates from slow queries.
 * - Index usage statistics from performance_schema.
 * - Invisible indexes for safe index removal testing.
 * - Functional (expression-based) indexes.
 * - Index hints (USE INDEX, FORCE INDEX, IGNORE INDEX).
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers
(
    customer_id   INT           PRIMARY KEY AUTO_INCREMENT,
    first_name    VARCHAR(50)   NOT NULL,
    last_name     VARCHAR(50)   NOT NULL,
    email         VARCHAR(100)  NOT NULL UNIQUE,
    country       VARCHAR(60)   NOT NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

CREATE TABLE orders
(
    order_id      INT           PRIMARY KEY AUTO_INCREMENT,
    customer_id   INT           NOT NULL,
    order_date    DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'pending',
    total_amount  DECIMAL(10,2) NOT NULL,
    INDEX idx_orders_customer  (customer_id),
    INDEX idx_orders_date      (order_date),
    INDEX idx_orders_status    (status),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE = InnoDB;

-- Populate with a small representative dataset
INSERT INTO customers (first_name, last_name, email, country)
VALUES
    ('Alice', 'Johnson', 'alice@example.com',  'US'),
    ('Bob',   'Smith',   'bob@example.com',    'UK'),
    ('Carol', 'Lee',     'carol@example.com',  'CA'),
    ('Dave',  'Brown',   'dave@example.com',   'US'),
    ('Eve',   'Wilson',  'eve@example.com',    'AU');

INSERT INTO orders (customer_id, order_date, status, total_amount)
VALUES
    (1, '2024-01-15', 'completed',  250.00),
    (1, '2024-03-20', 'completed',  180.00),
    (2, '2024-02-10', 'pending',    320.00),
    (3, '2024-01-30', 'shipped',    145.00),
    (4, '2024-04-05', 'completed',  410.00),
    (5, '2024-04-12', 'pending',     95.00);

-------------------------------------------------
-- Region: 1. Listing Indexes on a Database
-------------------------------------------------
/*
  1.1 All indexes in the current database.
*/
SELECT
    TABLE_NAME,
    INDEX_NAME,
    SEQ_IN_INDEX,
    COLUMN_NAME,
    NON_UNIQUE,
    NULLABLE,
    INDEX_TYPE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

/*
  1.2 Compact summary: index name, columns covered, uniqueness.
*/
SELECT
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS index_columns,
    IF(NON_UNIQUE = 0, 'UNIQUE', 'NON-UNIQUE')       AS uniqueness,
    INDEX_TYPE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE
ORDER BY TABLE_NAME, INDEX_NAME;

-------------------------------------------------
-- Region: 2. Unused Indexes (sys Schema)
-------------------------------------------------
/*
  2.1 sys.schema_unused_indexes lists indexes that have received no
       read access since the last server restart or stats reset.
       Review these candidates before dropping – they may still be
       needed for write-path uniqueness enforcement.
*/
SELECT *
FROM sys.schema_unused_indexes
WHERE object_schema = DATABASE();

/*
  2.2 For a quick check without sys: query performance_schema directly.
*/
SELECT
    OBJECT_SCHEMA AS table_schema,
    OBJECT_NAME   AS table_name,
    INDEX_NAME,
    COUNT_READ,
    COUNT_WRITE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
  AND COUNT_READ    = 0
  AND INDEX_NAME   <> 'PRIMARY'
ORDER BY OBJECT_NAME, INDEX_NAME;

-------------------------------------------------
-- Region: 3. Duplicate and Redundant Indexes
-------------------------------------------------
/*
  3.1 sys.schema_redundant_indexes identifies indexes that are a prefix
       of another index and therefore provide no additional query coverage.
*/
SELECT *
FROM sys.schema_redundant_indexes
WHERE table_schema = DATABASE();

/*
  3.2 Manual detection: find index pairs where one is a leading prefix
       of the other on the same table.
*/
SELECT
    a.TABLE_NAME,
    a.INDEX_NAME       AS redundant_index,
    a.index_columns    AS redundant_columns,
    b.INDEX_NAME       AS dominant_index,
    b.index_columns    AS dominant_columns
FROM (
    SELECT TABLE_NAME, INDEX_NAME,
           GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS index_columns
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
    GROUP BY TABLE_NAME, INDEX_NAME
) a
JOIN (
    SELECT TABLE_NAME, INDEX_NAME,
           GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS index_columns
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
    GROUP BY TABLE_NAME, INDEX_NAME
) b
  ON  a.TABLE_NAME    = b.TABLE_NAME
  AND a.INDEX_NAME   <> b.INDEX_NAME
  AND LOCATE(a.index_columns, b.index_columns) = 1
WHERE a.TABLE_NAME IN ('customers', 'orders');

-------------------------------------------------
-- Region: 4. Index Usage Statistics
-------------------------------------------------
/*
  4.1 Read / write counts per index since the last server restart.
       High COUNT_WRITE with low COUNT_READ may indicate
       a write-overhead-only index that could be dropped.
*/
SELECT
    OBJECT_NAME   AS table_name,
    INDEX_NAME,
    COUNT_STAR    AS total_accesses,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
ORDER BY OBJECT_NAME, INDEX_NAME;

-------------------------------------------------
-- Region: 5. Invisible Indexes
-------------------------------------------------
/*
  5.1 An invisible index is maintained by InnoDB but is not considered
       by the optimizer.  Use this to safely test removal before DROP.
*/
ALTER TABLE orders ALTER INDEX idx_orders_status INVISIBLE;

/*
  5.2 Force the optimizer to use invisible indexes for one session
       (useful to confirm the index is still valid and selectivity).
*/
SET SESSION optimizer_switch = 'use_invisible_indexes=on';

EXPLAIN SELECT order_id FROM orders WHERE status = 'completed';

-- Reset the session optimizer switch
SET SESSION optimizer_switch = 'use_invisible_indexes=off';

/*
  5.3 Restore the index to visible after confirming the workload is unaffected.
*/
ALTER TABLE orders ALTER INDEX idx_orders_status VISIBLE;

-------------------------------------------------
-- Region: 6. Functional (Expression-Based) Indexes
-------------------------------------------------
/*
  6.1 A functional index lets the optimizer use an index on the result
       of an expression – equivalent to SQL Server computed column indexes.

  6.2 Create an index on the month of order_date to speed up
       monthly-range queries without changing the column type.
*/
ALTER TABLE orders
    ADD INDEX idx_orders_order_month ((MONTH(order_date)));

/*
  6.3 Verify the optimizer chooses the functional index.
*/
EXPLAIN
SELECT order_id, order_date
FROM orders
WHERE MONTH(order_date) = 4;

-------------------------------------------------
-- Region: 7. Index Hints
-------------------------------------------------
/*
  7.1 USE INDEX: suggest a specific index (optimizer can still ignore it).
*/
SELECT order_id, customer_id, total_amount
FROM orders USE INDEX (idx_orders_customer)
WHERE customer_id = 1;

/*
  7.2 FORCE INDEX: override the optimizer and mandate index usage.
       Use sparingly – a query plan change may make this harmful.
*/
SELECT order_id, order_date
FROM orders FORCE INDEX (idx_orders_date)
WHERE order_date >= '2024-03-01';

/*
  7.3 IGNORE INDEX: exclude an index from the optimizer's consideration.
*/
SELECT order_id, status
FROM orders IGNORE INDEX (idx_orders_status)
WHERE status = 'pending';

-------------------------------------------------
-- Region: 8. Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
