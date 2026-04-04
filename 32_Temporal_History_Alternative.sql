/**************************************************************
 * MySQL 8.0 Temporal History Alternative Tutorial
 * MySQL does not support ISO SQL SYSTEM-VERSIONED
 * temporal tables natively.  This script shows practical
 * alternatives that provide the same capabilities:
 * - Trigger-based history tables (insert a copy of old
 *   rows into a shadow table on every UPDATE / DELETE).
 * - Querying the current state and full history.
 * - Querying the row "as of" a specific point in time.
 * - Querying changes between two time points.
 * - Disabling and auditing history.
 * - JSON-based column-change diff.
 *
 *  NOTE: MySQL 8.0 does support application-time period tables
 *        (WITH SYSTEM TIME on the application side) and temporal
 *        predicates in the SELECT WHERE clause when the table
 *        is defined with PERIOD FOR VALID_TIME.  That lighter
 *        variant is shown at the end (Region 6).
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TRIGGER  IF EXISTS trg_employee_update;
DROP TRIGGER  IF EXISTS trg_employee_delete;
DROP TABLE    IF EXISTS employee_history;
DROP TABLE    IF EXISTS employee;

-------------------------------------------------
-- Region: 1. Creating the Live Table and History Table
-------------------------------------------------
/*
  1.1 The live (current-state) table.
*/
CREATE TABLE employee
(
    employee_id INT           PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100)  NOT NULL,
    position    VARCHAR(100)  NOT NULL,
    salary      DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

/*
  1.2 The history table mirrors every column and adds temporal metadata.
       row_start / row_end record the validity window of each version.
       change_type records why the row was archived (UPDATE or DELETE).
*/
CREATE TABLE employee_history
(
    history_id  INT           PRIMARY KEY AUTO_INCREMENT,
    employee_id INT           NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    position    VARCHAR(100)  NOT NULL,
    salary      DECIMAL(10,2) NOT NULL,
    row_start   DATETIME(6)   NOT NULL,
    row_end     DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    change_type ENUM('UPDATE','DELETE') NOT NULL,
    changed_by  VARCHAR(100)  NOT NULL DEFAULT (CURRENT_USER()),
    INDEX ix_hist_employee (employee_id),
    INDEX ix_hist_row_end  (row_end)
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 2. Triggers to Capture History
-------------------------------------------------
/*
  2.1 BEFORE UPDATE: archive the old row before it is overwritten.
       row_start is set to CURRENT_TIMESTAMP(6) as a proxy for the time
       the row was originally created or last modified.  A more precise
       approach is to carry a valid_from column on the live table.
*/
DELIMITER //

CREATE TRIGGER trg_employee_update
BEFORE UPDATE ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_history
        (employee_id, name,     position,     salary,
         row_start,               row_end,                change_type)
    VALUES
        (OLD.employee_id, OLD.name, OLD.position, OLD.salary,
         NOW(6) - INTERVAL 1 MICROSECOND, NOW(6),         'UPDATE');
END //

/*
  2.2 BEFORE DELETE: archive the deleted row.
*/
CREATE TRIGGER trg_employee_delete
BEFORE DELETE ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_history
        (employee_id, name,     position,     salary,
         row_start,               row_end,               change_type)
    VALUES
        (OLD.employee_id, OLD.name, OLD.position, OLD.salary,
         NOW(6) - INTERVAL 1 MICROSECOND, NOW(6),        'DELETE');
END //

DELIMITER ;

-------------------------------------------------
-- Region: 3. Inserting and Modifying Data
-------------------------------------------------
/*
  3.1 Insert initial employees.
*/
INSERT INTO employee (employee_id, name, position, salary)
VALUES
    (1, 'Alice',   'Manager',            90000.00),
    (2, 'Bob',     'Developer',          75000.00),
    (3, 'Charlie', 'Analyst',            68000.00);

/*
  3.2 Update Bob's salary and position.
*/
UPDATE employee SET salary = 80000.00, position = 'Senior Developer'
WHERE employee_id = 2;

/*
  3.3 Update Alice's salary.
*/
UPDATE employee SET salary = 95000.00
WHERE employee_id = 1;

/*
  3.4 Delete Charlie.
*/
DELETE FROM employee WHERE employee_id = 3;

-------------------------------------------------
-- Region: 4. Querying Data
-------------------------------------------------
/*
  4.1 Current state.
*/
SELECT * FROM employee;

/*
  4.2 Full history of all changes.
*/
SELECT
    h.history_id,
    h.employee_id,
    h.name,
    h.position,
    h.salary,
    h.row_start,
    h.row_end,
    h.change_type,
    h.changed_by
FROM employee_history h
ORDER BY h.employee_id, h.row_end;

/*
  4.3 See all versions (current + historical) of Bob.
*/
SELECT 'current'  AS source, employee_id, name, position, salary, NOW(6) AS valid_from
FROM   employee
WHERE  employee_id = 2
UNION ALL
SELECT 'history', employee_id, name, position, salary, row_end
FROM   employee_history
WHERE  employee_id = 2
ORDER  BY valid_from;

/*
  4.4 "As of" query: what did employee 2 look like 1 second ago?
       Replace the interval with an actual snapshot timestamp.
*/
SET @as_of = NOW(6) - INTERVAL 1 SECOND;

-- If the employee exists in the current table and was created before @as_of:
SELECT employee_id, name, position, salary
FROM   employee
WHERE  employee_id = 2
UNION ALL
-- Fall back to the most recent history row valid at @as_of:
SELECT h.employee_id, h.name, h.position, h.salary
FROM   employee_history h
WHERE  h.employee_id = 2
  AND  h.row_end <= @as_of
ORDER  BY row_end DESC
LIMIT  1;

/*
  4.5 Changes between two time points.
*/
SET @t_start = NOW(6) - INTERVAL 10 MINUTE;
SET @t_end   = NOW(6);

SELECT employee_id, name, position, salary, change_type, row_end AS changed_at
FROM   employee_history
WHERE  row_end BETWEEN @t_start AND @t_end
ORDER  BY row_end;

-------------------------------------------------
-- Region: 5. JSON Column-Change Diff
-------------------------------------------------
/*
  5.1 For a richer audit, store a before/after JSON diff instead of
       (or in addition to) the full row copy.  Requires adding a
       json_diff column to the history table.
*/
ALTER TABLE employee_history
    ADD COLUMN json_before JSON  AFTER salary,
    ADD COLUMN json_after  JSON  AFTER json_before;

/*
  5.2 Demonstrate a manual diff insert (would be placed inside a trigger
       in a real implementation).
*/
SET @before = JSON_OBJECT('salary', 75000.00, 'position', 'Developer');
SET @after  = JSON_OBJECT('salary', 80000.00, 'position', 'Senior Developer');

-- Show changed keys only
SELECT
    jt.field_name,
    JSON_EXTRACT(@before, CONCAT('$.', jt.field_name)) AS old_value,
    JSON_EXTRACT(@after,  CONCAT('$.', jt.field_name)) AS new_value
FROM JSON_TABLE(
    JSON_KEYS(@after),
    '$[*]'
    COLUMNS (field_name VARCHAR(100) PATH '$')
) AS jt
WHERE JSON_EXTRACT(@before, CONCAT('$.', jt.field_name))
   <> JSON_EXTRACT(@after,  CONCAT('$.', jt.field_name));

-------------------------------------------------
-- Region: 6. Application-Time Period Table
-------------------------------------------------
/*
  6.1 MySQL 8.0 supports PERIOD FOR (application-time period) columns
       and the overlaps / contains predicates for SCD type-2 patterns.
*/
DROP TABLE IF EXISTS product_price;

CREATE TABLE product_price
(
    product_id  INT            NOT NULL,
    price       DECIMAL(10,2)  NOT NULL,
    valid_from  DATE           NOT NULL,
    valid_to    DATE           NOT NULL,
    PERIOD FOR valid_time (valid_from, valid_to),
    PRIMARY KEY (product_id, valid_from)
) ENGINE = InnoDB;

INSERT INTO product_price (product_id, price, valid_from, valid_to)
VALUES
    (1, 100.00, '2024-01-01', '2024-06-30'),
    (1, 110.00, '2024-07-01', '2024-12-31'),
    (1, 120.00, '2025-01-01', '9999-12-31');

/*
  6.2 Find the price for product 1 on a specific date.
*/
SET @query_date = '2024-09-15';

SELECT product_id, price, valid_from, valid_to
FROM product_price
WHERE product_id = 1
  AND @query_date BETWEEN valid_from AND valid_to;

/*
  6.3 Using the OVERLAPS predicate (requires PERIOD FOR columns).
*/
SELECT product_id, price, valid_from, valid_to
FROM   product_price
WHERE  product_id = 1
  AND  valid_time OVERLAPS (DATE '2024-06-01', DATE '2024-08-01');

-------------------------------------------------
-- Region: 7. Cleanup
-------------------------------------------------
DROP TRIGGER IF EXISTS trg_employee_update;
DROP TRIGGER IF EXISTS trg_employee_delete;
DROP TABLE   IF EXISTS employee_history;
DROP TABLE   IF EXISTS employee;
DROP TABLE   IF EXISTS product_price;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
