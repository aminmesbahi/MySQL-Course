/**************************************************************
 * MySQL 8.0: Bulk Data Operations
 * This script demonstrates high-performance methods for
 * loading and inserting large volumes of data:
 *  1. LOAD DATA INFILE – fastest server-side bulk load.
 *  2. LOAD DATA LOCAL INFILE – client-side file path.
 *  3. Multi-row INSERT batches.
 *  4. INSERT IGNORE – skip duplicate-key errors.
 *  5. REPLACE INTO – delete-then-insert on duplicate key.
 *  6. INSERT ... ON DUPLICATE KEY UPDATE (upsert).
 *  7. Transaction wrapping for batch performance.
 *  8. Disabling keys during bulk load.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS bulk_orders;
DROP TABLE IF EXISTS product_catalog;
DROP TABLE IF EXISTS staging_products;

CREATE TABLE product_catalog
(
    product_id   INT           PRIMARY KEY AUTO_INCREMENT,
    sku          VARCHAR(20)   NOT NULL UNIQUE,
    product_name VARCHAR(100)  NOT NULL,
    category     VARCHAR(50)   NOT NULL,
    price        DECIMAL(10,2) NOT NULL,
    stock_qty    INT           NOT NULL DEFAULT 0
) ENGINE = InnoDB;

CREATE TABLE bulk_orders
(
    order_id    INT           PRIMARY KEY AUTO_INCREMENT,
    customer_id INT           NOT NULL,
    order_date  DATE          NOT NULL,
    amount      DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE staging_products
(
    sku          VARCHAR(20)   NOT NULL,
    product_name VARCHAR(100)  NOT NULL,
    price        DECIMAL(10,2) NOT NULL,
    stock_qty    INT           NOT NULL DEFAULT 0
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 1. LOAD DATA INFILE
-------------------------------------------------
/*
  1.1  LOAD DATA INFILE is the fastest way to bulk-load a CSV (or
       delimited text) file into a MySQL table.  The file path refers
       to a location on the SERVER's filesystem.

  Requirements:
   - The user needs the FILE privilege.
   - The file must be in the directory specified by @@secure_file_priv,
     or @@secure_file_priv must be empty (disabled).
   - On Windows the path uses forward slashes or escaped backslashes.
*/
SHOW VARIABLES LIKE 'secure_file_priv';

/*
  Example CSV (product_load.csv):
      SKU001,"Widget A","Electronics",49.99,100
      SKU002,"Widget B","Electronics",19.99,250
      SKU003,"Gadget X","Tools",99.99,50
*/

-- Typical LOAD DATA INFILE usage:
/*
LOAD DATA INFILE '/var/lib/mysql-files/product_load.csv'
INTO TABLE product_catalog
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS                               -- skip header row
(sku, product_name, category, price, stock_qty);
*/

SELECT 'See commented LOAD DATA INFILE block above.' AS note;

-------------------------------------------------
-- Region: 2. LOAD DATA LOCAL INFILE
-------------------------------------------------
/*
  2.1  LOAD DATA LOCAL INFILE reads the file from the CLIENT machine.
       The MySQL client library streams the file to the server.

  Requirements:
   - The server must have local_infile = ON.
   - The client connection must also enable LOCAL INFILE
     (--local-infile=1 CLI flag, or AllowLoadDataLocalInfile=true in connectors).
*/
SHOW VARIABLES LIKE 'local_infile';

-- Enable on the server (requires SUPER or SYSTEM_VARIABLES_ADMIN):
-- SET GLOBAL local_infile = ON;

/*
LOAD DATA LOCAL INFILE 'C:/data/product_load.csv'
INTO TABLE product_catalog
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\r\n'
IGNORE 1 ROWS
(sku, product_name, category, price, stock_qty);
*/

SELECT 'See commented LOAD DATA LOCAL INFILE block above.' AS note;

-------------------------------------------------
-- Region: 3. Multi-Row INSERT Batches
-------------------------------------------------
/*
  3.1  Sending multiple rows in a single INSERT statement is much faster
       than executing one INSERT per row because it reduces round-trips
       and transaction commits.  Aim for batches of ~1 000 – 5 000 rows
       to balance memory use and performance.
*/

-- Single-row INSERT (slow for large volumes)
INSERT INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES ('SKU001', 'Widget A', 'Electronics', 49.99, 100);

-- Multi-row INSERT (fast)
INSERT INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES
    ('SKU002', 'Widget B',   'Electronics', 19.99, 250),
    ('SKU003', 'Gadget X',   'Tools',        99.99,  50),
    ('SKU004', 'Bolt Pack',  'Hardware',      4.99, 500),
    ('SKU005', 'Drill Bit',  'Hardware',     14.99, 300);

SELECT COUNT(*) AS loaded FROM product_catalog;

-------------------------------------------------
-- Region: 4. INSERT IGNORE
-------------------------------------------------
/*
  4.1  INSERT IGNORE silently skips rows that would cause a duplicate-key
       or other ignorable error.  The statement continues and a warning
       is issued instead of an error.
*/
INSERT IGNORE INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES
    ('SKU001', 'Widget A Duplicate', 'Electronics', 59.99, 50),  -- duplicate SKU; skipped
    ('SKU006', 'New Item',          'Tools',        24.99, 80);  -- new row; inserted

SHOW WARNINGS;

SELECT sku, product_name FROM product_catalog WHERE sku IN ('SKU001','SKU006');

-------------------------------------------------
-- Region: 5. REPLACE INTO
-------------------------------------------------
/*
  5.1  REPLACE INTO first deletes any existing row that conflicts on a
       PRIMARY KEY or UNIQUE index, then inserts the new row.
       Auto-increment IDs will change on replacement.
       Use when you want a full row overwrite and do not care about the old ID.
*/
REPLACE INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES ('SKU003', 'Gadget X Pro', 'Tools', 119.99, 60);

SELECT sku, product_name, price FROM product_catalog WHERE sku = 'SKU003';

-------------------------------------------------
-- Region: 6. INSERT ... ON DUPLICATE KEY UPDATE (Upsert)
-------------------------------------------------
/*
  6.1  ON DUPLICATE KEY UPDATE is the preferred upsert mechanism.
       If no conflict occurs the row is inserted; if a unique key conflicts
       only the listed columns are updated on the existing row.
       The AUTO_INCREMENT ID is preserved (unlike REPLACE INTO).
*/
INSERT INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES ('SKU002', 'Widget B', 'Electronics', 22.99, 300)
ON DUPLICATE KEY UPDATE
    price     = VALUES(price),
    stock_qty = stock_qty + VALUES(stock_qty);   -- accumulate stock

SELECT sku, price, stock_qty FROM product_catalog WHERE sku = 'SKU002';

-- MySQL 8.0.19+ alias syntax (cleaner, avoids deprecated VALUES() in UPDATE):
INSERT INTO product_catalog (sku, product_name, category, price, stock_qty)
VALUES ('SKU004', 'Bolt Pack', 'Hardware', 5.49, 200) AS new_row
ON DUPLICATE KEY UPDATE
    price     = new_row.price,
    stock_qty = product_catalog.stock_qty + new_row.stock_qty;

SELECT sku, price, stock_qty FROM product_catalog WHERE sku = 'SKU004';

-------------------------------------------------
-- Region: 7. Transaction Wrapping for Batch Performance
-------------------------------------------------
/*
  7.1  By default MySQL commits after every statement (autocommit = ON).
       Wrapping a batch of INSERTs in an explicit transaction reduces the
       number of fsync calls to the redo log, dramatically improving throughput.
*/
SET autocommit = 0;
START TRANSACTION;

INSERT INTO bulk_orders (customer_id, order_date, amount) VALUES
    (1, '2024-01-01',  250.00),
    (1, '2024-01-02',  125.50),
    (2, '2024-01-03',   80.00),
    (2, '2024-01-04', 3200.00),
    (3, '2024-01-05',  540.75);

COMMIT;
SET autocommit = 1;

SELECT COUNT(*) AS orders_loaded FROM bulk_orders;

-------------------------------------------------
-- Region: 8. Disable Keys During Bulk Load (MyISAM / Non-unique Indexes)
-------------------------------------------------
/*
  8.1  For InnoDB the best practice is to sort the data by PRIMARY KEY
       before loading so inserts are sequential and minimise page splits.

  8.2  For non-unique secondary indexes you can defer their maintenance
       by disabling them, loading, then rebuilding:
*/
-- Disable non-unique secondary indexes (InnoDB: works for non-unique keys)
ALTER TABLE staging_products DISABLE KEYS;

INSERT INTO staging_products (sku, product_name, price, stock_qty)
VALUES
    ('SP001', 'Stage Item 1', 9.99,  50),
    ('SP002', 'Stage Item 2', 14.99, 75),
    ('SP003', 'Stage Item 3', 19.99, 25);

-- Re-enable and rebuild indexes after load
ALTER TABLE staging_products ENABLE KEYS;

/*
  8.3  For InnoDB tables with large unique indexes consider:
       1. Sort the CSV by the primary key column before LOAD DATA INFILE.
       2. Increase innodb_buffer_pool_size to cache more index pages.
       3. Set innodb_flush_log_at_trx_commit = 2 temporarily (less durable).
*/
SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS staging_products;
DROP TABLE IF EXISTS bulk_orders;
DROP TABLE IF EXISTS product_catalog;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
