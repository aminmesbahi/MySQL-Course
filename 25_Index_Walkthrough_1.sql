/**************************************************************
 * MySQL 8.0 Index Walkthrough – Part 1
 * This script demonstrates how InnoDB stores and
 * organises index pages, and shows how to inspect
 * index structures using INFORMATION_SCHEMA and the
 * sys schema.  It covers:
 * - Heap-like tables vs. tables with a clustered index.
 * - How InnoDB B-tree pages fill and split.
 * - Analysing index fragmentation with INFORMATION_SCHEMA.
 * - Rebuilding tables and indexes to reclaim space.
 * - Verifying index usage with sys.schema_unused_indexes
 *   and performance_schema.table_io_waits_summary.
 * - EXPLAIN and EXPLAIN ANALYZE for execution plan inspection.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS heap_demo;
DROP TABLE IF EXISTS clustered_demo;

-------------------------------------------------
-- Region: 1. Heap-Like Table (No Explicit PK)
-------------------------------------------------
/*
  1.1 InnoDB does not have true heaps – it always stores rows in a
       B-tree ordered by the primary key.  When no PK is defined
       InnoDB creates a hidden 6-byte row-id column as the clustering
       key.  The result behaves like a heap from the query perspective.
*/
CREATE TABLE heap_demo
(
    fixed_col CHAR(200) NOT NULL   -- fixed-width column to fill pages quickly
) ENGINE = InnoDB;

/*
  1.2 Insert enough rows to span several pages.
       A single InnoDB page is 16 KB by default;
       a 200-byte row fits ~70 rows per leaf page.
*/
INSERT INTO heap_demo (fixed_col)
SELECT REPEAT('A', 200)
FROM (
    SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
) t1
CROSS JOIN (
    SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
) t2;   -- 64 rows

/*
  1.3 Check the storage footprint in INFORMATION_SCHEMA.
*/
SELECT
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    AVG_ROW_LENGTH,
    DATA_LENGTH,
    INDEX_LENGTH,
    DATA_FREE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'heap_demo';

-------------------------------------------------
-- Region: 2. Table with a Clustered Index (PK)
-------------------------------------------------
/*
  2.1 InnoDB stores rows in PK order within the B-tree leaf pages.
       Each non-clustered (secondary) index leaf also stores the PK
       value so InnoDB can find the rest of the row via a clustered
       index lookup (called a "bookmark lookup").
*/
CREATE TABLE clustered_demo
(
    id        INT          NOT NULL,
    fixed_col CHAR(200)    NOT NULL,
    PRIMARY KEY (id)         -- clustered index on id
) ENGINE = InnoDB;

/*
  2.2 Insert rows in ascending order – pages fill sequentially, no splits.
*/
INSERT INTO clustered_demo (id, fixed_col)
SELECT n, REPEAT('B', 200)
FROM (
    WITH RECURSIVE seq(n) AS (
        SELECT 1
        UNION ALL
        SELECT n + 1 FROM seq WHERE n < 64
    )
    SELECT n FROM seq
) numbers;

/*
  2.3 Verify storage after sequential inserts.
*/
SELECT
    TABLE_NAME,
    DATA_LENGTH,
    INDEX_LENGTH,
    DATA_FREE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'clustered_demo';

-------------------------------------------------
-- Region: 3. Observing Page Splits (Random Inserts)
-------------------------------------------------
/*
  3.1 Insert rows with a random PK to induce page splits.
       InnoDB splits a 16-KB page roughly when it is ~69 % full;
       after a split both resulting pages are ~50 % full – this is
       the source of index fragmentation.
*/
DROP TABLE IF EXISTS split_demo;

CREATE TABLE split_demo
(
    id        INT       NOT NULL,
    pad_col   CHAR(200) NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- pseudo-random ids using a simple seed
INSERT INTO split_demo (id, pad_col)
VALUES
    (500,  REPEAT('X', 200)),
    (100,  REPEAT('X', 200)),
    (900,  REPEAT('X', 200)),
    (300,  REPEAT('X', 200)),
    (700,  REPEAT('X', 200)),
    (50,   REPEAT('X', 200)),
    (750,  REPEAT('X', 200)),
    (250,  REPEAT('X', 200)),
    (600,  REPEAT('X', 200)),
    (150,  REPEAT('X', 200));

/*
  3.2 Inspect DATA_FREE to see space reserved after splits but not used
       by live data ("fragmented" free space inside the tablespace).
*/
SELECT
    TABLE_NAME,
    DATA_LENGTH,
    DATA_FREE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'split_demo';

-------------------------------------------------
-- Region: 4. Adding Secondary Indexes
-------------------------------------------------
/*
  4.1 Add a nonclustered (secondary) index on pad_col.
*/
ALTER TABLE split_demo ADD INDEX idx_split_padcol (pad_col(20));

/*
  4.2 List all indexes for the table via INFORMATION_SCHEMA.
*/
SELECT
    INDEX_NAME,
    SEQ_IN_INDEX,
    COLUMN_NAME,
    NON_UNIQUE,
    INDEX_TYPE,
    SUB_PART
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'split_demo'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;

-------------------------------------------------
-- Region: 5. Rebuilding a Table to Reduce Fragmentation
-------------------------------------------------
/*
  5.1 OPTIMIZE TABLE rebuilds the table inline, reclaims DATA_FREE space,
       and defragments all leaf pages.  For large production tables
       prefer ALTER TABLE ... ENGINE=InnoDB which uses the online DDL path.
*/
OPTIMIZE TABLE split_demo;

SELECT
    TABLE_NAME,
    DATA_LENGTH,
    DATA_FREE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'split_demo';

-------------------------------------------------
-- Region: 6. EXPLAIN for Execution Plan Inspection
-------------------------------------------------
/*
  6.1 Classic EXPLAIN shows whether MySQL uses the index.
*/
EXPLAIN
SELECT id, pad_col
FROM split_demo
WHERE id BETWEEN 100 AND 500;

/*
  6.2 EXPLAIN FORMAT=JSON provides richer detail including
       estimated cost and filter percentages.
*/
EXPLAIN FORMAT = JSON
SELECT id, pad_col
FROM split_demo
WHERE id BETWEEN 100 AND 500;

/*
  6.3 EXPLAIN ANALYZE (MySQL 8.0.18+) executes the query and reports
       actual row counts and elapsed times next to each plan node.
*/
EXPLAIN ANALYZE
SELECT id, pad_col
FROM split_demo
WHERE pad_col LIKE 'X%';

-------------------------------------------------
-- Region: 7. Identifying Fragmented Tables
-------------------------------------------------
/*
  7.1 Find tables in the current database with significant free space
       inside the tablespace (potential fragmentation).
*/
SELECT
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND(DATA_LENGTH  / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND(DATA_FREE    / 1024 / 1024, 2) AS free_mb,
    ROUND(DATA_FREE * 100.0
          / NULLIF(DATA_LENGTH + INDEX_LENGTH + DATA_FREE, 0), 1) AS fragmentation_pct
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND ENGINE       = 'InnoDB'
ORDER BY DATA_FREE DESC;

-------------------------------------------------
-- Region: 8. Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS heap_demo;
DROP TABLE IF EXISTS clustered_demo;
DROP TABLE IF EXISTS split_demo;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
