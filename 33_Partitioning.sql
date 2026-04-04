/**************************************************************
 * MySQL 8.0 Table Partitioning Tutorial
 * This script demonstrates how to implement and
 * manage table partitioning in MySQL 8.0.  It covers:
 * - RANGE, LIST, HASH, and KEY partitioning strategies.
 * - Sub-partitioning (composite partitioning).
 * - Adding, dropping, merging, and reorganising partitions.
 * - Partition pruning and verifying the optimizer uses it.
 * - Archiving data with EXCHANGE PARTITION.
 * - Partitioned index maintenance.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS sales_range;
DROP TABLE IF EXISTS sales_list;
DROP TABLE IF EXISTS sales_hash;
DROP TABLE IF EXISTS sales_key;
DROP TABLE IF EXISTS sales_archive;

-------------------------------------------------
-- Region: 1. RANGE Partitioning
-------------------------------------------------
/*
  1.1 Partition by ranges of sale_id.
       RANGE LEFT semantics: the boundary value belongs to the left partition.
       MySQL RANGE is exclusive on the right boundary.
*/
CREATE TABLE sales_range
(
    sale_id    INT           NOT NULL,
    sale_date  DATE          NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    region     VARCHAR(20)   NOT NULL,
    PRIMARY KEY (sale_id)
)
ENGINE = InnoDB
PARTITION BY RANGE (sale_id)
(
    PARTITION p0 VALUES LESS THAN (1001),
    PARTITION p1 VALUES LESS THAN (2001),
    PARTITION p2 VALUES LESS THAN (3001),
    PARTITION p3 VALUES LESS THAN (4001),
    PARTITION p_max VALUES LESS THAN MAXVALUE
);

/*
  1.2 Insert rows that will land in different partitions.
*/
INSERT INTO sales_range (sale_id, sale_date, amount, region)
VALUES
    ( 500, '2024-01-15',  100.00, 'US'),
    (1500, '2024-02-10',  200.00, 'EU'),
    (2500, '2024-03-05',  300.00, 'APAC'),
    (3500, '2024-04-20',  400.00, 'US'),
    (4500, '2024-05-30',  500.00, 'EU');

/*
  1.3 Query a RANGE partition directly.
*/
SELECT * FROM sales_range WHERE sale_id BETWEEN 1000 AND 2000;

/*
  1.4 Verify partition pruning via EXPLAIN.
*/
EXPLAIN
SELECT * FROM sales_range
WHERE sale_id < 1001;         -- should report partition: p0

-------------------------------------------------
-- Region: 2. RANGE COLUMNS Partitioning (by Date)
-------------------------------------------------
/*
  2.1 RANGE COLUMNS supports non-integer columns and multi-column ranges.
       Common pattern: partition by year-month of a date column.
*/
DROP TABLE IF EXISTS orders_by_date;

CREATE TABLE orders_by_date
(
    order_id    INT  NOT NULL,
    order_date  DATE NOT NULL,
    amount      DECIMAL(10,2),
    PRIMARY KEY (order_id, order_date)
)
ENGINE = InnoDB
PARTITION BY RANGE COLUMNS (order_date)
(
    PARTITION p_2023_H1 VALUES LESS THAN ('2023-07-01'),
    PARTITION p_2023_H2 VALUES LESS THAN ('2024-01-01'),
    PARTITION p_2024_H1 VALUES LESS THAN ('2024-07-01'),
    PARTITION p_2024_H2 VALUES LESS THAN ('2025-01-01'),
    PARTITION p_future  VALUES LESS THAN (MAXVALUE)
);

INSERT INTO orders_by_date VALUES
    (1, '2023-03-10', 150.00),
    (2, '2023-09-22', 230.00),
    (3, '2024-02-14', 310.00),
    (4, '2024-08-01', 420.00);

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME   = 'orders_by_date';

-------------------------------------------------
-- Region: 3. LIST Partitioning
-------------------------------------------------
/*
  3.1 Partition by discrete values of the region column (mapped to integers).
*/
CREATE TABLE sales_list
(
    sale_id   INT           NOT NULL,
    sale_date DATE          NOT NULL,
    amount    DECIMAL(10,2) NOT NULL,
    region_id INT           NOT NULL,   -- 1=US, 2=EU, 3=APAC, 4=LatAm
    PRIMARY KEY (sale_id)
)
ENGINE = InnoDB
PARTITION BY LIST (region_id)
(
    PARTITION p_us   VALUES IN (1),
    PARTITION p_eu   VALUES IN (2),
    PARTITION p_apac VALUES IN (3),
    PARTITION p_latam VALUES IN (4)
);

INSERT INTO sales_list VALUES
    (1, '2024-01-10', 100.00, 1),
    (2, '2024-02-20', 200.00, 2),
    (3, '2024-03-15', 300.00, 3),
    (4, '2024-04-05', 400.00, 4);

SELECT * FROM sales_list PARTITION (p_us);

-------------------------------------------------
-- Region: 4. HASH Partitioning
-------------------------------------------------
/*
  4.1 HASH spreads data evenly across N buckets using MOD(expr, N).
*/
CREATE TABLE sales_hash
(
    sale_id  INT  NOT NULL,
    sale_date DATE NOT NULL,
    amount   DECIMAL(10,2),
    PRIMARY KEY (sale_id)
)
ENGINE = InnoDB
PARTITION BY HASH (sale_id)
PARTITIONS 4;

INSERT INTO sales_hash VALUES
    (1, '2024-01-01', 100),
    (2, '2024-01-02', 200),
    (5, '2024-01-05', 500),
    (7, '2024-01-07', 700);

SELECT PARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME   = 'sales_hash';

-------------------------------------------------
-- Region: 5. KEY Partitioning
-------------------------------------------------
/*
  5.1 KEY partitioning is similar to HASH but uses MySQL's internal hash
       function and works with string columns.
*/
CREATE TABLE sales_key
(
    sale_id  INT         NOT NULL,
    region   VARCHAR(20) NOT NULL,
    amount   DECIMAL(10,2),
    PRIMARY KEY (sale_id, region)
)
ENGINE = InnoDB
PARTITION BY KEY (region)
PARTITIONS 3;

INSERT INTO sales_key VALUES
    (1, 'US',   100),
    (2, 'EU',   200),
    (3, 'APAC', 300);

-------------------------------------------------
-- Region: 6. Adding and Dropping Partitions
-------------------------------------------------
/*
  6.1 Add a new partition to the RANGE table for 2025 data.
       The existing p_max partition must be reorganised first.
*/
ALTER TABLE sales_range
    REORGANIZE PARTITION p_max INTO
    (
        PARTITION p4    VALUES LESS THAN (5001),
        PARTITION p_max VALUES LESS THAN MAXVALUE
    );

SHOW CREATE TABLE sales_range\G

/*
  6.2 Drop the first partition (removes rows in that partition).
       Use EXCHANGE (Region 8) to archive rows before dropping.
*/
-- ALTER TABLE sales_range DROP PARTITION p0;   -- commented out: destructive

-------------------------------------------------
-- Region: 7. Merging Partitions
-------------------------------------------------
/*
  7.1 Merge p1 and p2 of sales_range into a single partition.
*/
ALTER TABLE sales_range
    REORGANIZE PARTITION p1, p2 INTO
    (
        PARTITION p1_2 VALUES LESS THAN (3001)
    );

SELECT PARTITION_NAME, PARTITION_DESCRIPTION
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME   = 'sales_range';

-------------------------------------------------
-- Region: 8. EXCHANGE PARTITION (Archiving)
-------------------------------------------------
/*
  8.1 EXCHANGE swaps a partition's data with a matching plain table.
       Use it to archive old data without scanning the full table.
*/
CREATE TABLE sales_archive
(
    sale_id    INT           NOT NULL,
    sale_date  DATE          NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    region     VARCHAR(20)   NOT NULL,
    PRIMARY KEY (sale_id)
) ENGINE = InnoDB;   -- no partitioning on the archive table

-- Move partition p0 data into sales_archive
ALTER TABLE sales_range EXCHANGE PARTITION p0 WITH TABLE sales_archive;

-- Verify: sales_archive now holds the p0 rows
SELECT * FROM sales_archive;
SELECT * FROM sales_range PARTITION (p0);       -- should be empty

-- Swap back if needed
ALTER TABLE sales_range EXCHANGE PARTITION p0 WITH TABLE sales_archive;

-------------------------------------------------
-- Region: 9. Sub-Partitioning (Composite Partitioning)
-------------------------------------------------
/*
  9.1 Sub-partition a RANGE-partitioned table further by HASH,
       giving finer-grained data distribution.
*/
DROP TABLE IF EXISTS subpart_sales;

CREATE TABLE subpart_sales
(
    sale_id  INT  NOT NULL,
    sale_date DATE NOT NULL,
    amount   DECIMAL(10,2),
    PRIMARY KEY (sale_id, sale_date)
)
ENGINE = InnoDB
PARTITION BY RANGE (YEAR(sale_date))
SUBPARTITION BY HASH (sale_id)
SUBPARTITIONS 2
(
    PARTITION p_2023 VALUES LESS THAN (2024),
    PARTITION p_2024 VALUES LESS THAN (2025),
    PARTITION p_2025 VALUES LESS THAN MAXVALUE
);

INSERT INTO subpart_sales VALUES
    (1, '2023-06-01', 100),
    (2, '2023-12-15', 200),
    (3, '2024-03-10', 300),
    (4, '2024-11-20', 400);

SELECT PARTITION_NAME, SUBPARTITION_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME   = 'subpart_sales';

-------------------------------------------------
-- Region: 10. Partition Maintenance Queries
-------------------------------------------------
/*
  10.1 List all partitions across all partitioned tables in the current database.
*/
SELECT
    TABLE_NAME,
    PARTITION_NAME,
    SUBPARTITION_NAME,
    PARTITION_METHOD,
    PARTITION_EXPRESSION,
    PARTITION_DESCRIPTION,
    TABLE_ROWS
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND PARTITION_NAME IS NOT NULL
ORDER BY TABLE_NAME, PARTITION_ORDINAL_POSITION;

/*
  10.2 Rebuild (OPTIMIZE) a specific partition to reclaim fragmented space.
*/
-- ALTER TABLE sales_range OPTIMIZE PARTITION p_max;

/*
  10.3 Analyse partition statistics.
*/
-- ALTER TABLE sales_range ANALYZE PARTITION p1_2;

-------------------------------------------------
-- Region: 11. Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS subpart_sales;
DROP TABLE IF EXISTS sales_archive;
DROP TABLE IF EXISTS orders_by_date;
DROP TABLE IF EXISTS sales_range;
DROP TABLE IF EXISTS sales_list;
DROP TABLE IF EXISTS sales_hash;
DROP TABLE IF EXISTS sales_key;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
