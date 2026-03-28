/**************************************************************
 * MySQL 8.0 Expressions Tutorial
 * This script demonstrates common MySQL expression
 * types, including:
 * - CASE expressions (simple and searched) for
 *   conditional logic and data categorization.
 * - COALESCE to handle NULL values and provide defaults.
 * - NULLIF to avoid divide-by-zero and suppress
 *   sentinel values.
 * - IFNULL and IF as MySQL shorthand alternatives.
 * - OUTPUT-equivalent pattern using LAST_INSERT_ID.
 * - AT TIME ZONE equivalent via CONVERT_TZ.
 * - Optimizer hints with SELECT statement hints.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS sample_data;

CREATE TABLE sample_data
(
    id         INT           PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100)  NOT NULL,
    age        INT           NOT NULL,
    salary     DECIMAL(10,2),
    department VARCHAR(100)  NOT NULL,
    notes      TEXT
) ENGINE = InnoDB;

INSERT INTO sample_data (name, age, salary, department, notes)
VALUES
    ('Alice',   30,  60000.00, 'HR',      'Initial note for Alice'),
    ('Bob',     25,  NULL,     'IT',      'Initial note for Bob'),
    ('Charlie', 35,  80000.00, 'Finance', 'Initial note for Charlie'),
    ('David',   40,  90000.00, 'IT',      'Initial note for David'),
    ('Eve',     28,  NULL,     'HR',      'Initial note for Eve');

-------------------------------------------------
-- Region: 1. Searched CASE Expression
-------------------------------------------------
/*
  1.1 Classify employees into age groups.
*/
SELECT
    name,
    age,
    CASE
        WHEN age < 30           THEN 'Young'
        WHEN age BETWEEN 30 AND 39 THEN 'Adult'
        ELSE                         'Senior'
    END AS age_group
FROM sample_data;

/*
  1.2 Handle NULL salary with a searched CASE.
*/
SELECT
    name,
    salary,
    CASE
        WHEN salary IS NULL THEN 'Salary not provided'
        ELSE                     'Salary provided'
    END AS salary_status
FROM sample_data;

-------------------------------------------------
-- Region: 2. Simple CASE Expression
-------------------------------------------------
/*
  2.1 Map department codes to descriptive labels.
*/
SELECT
    name,
    department,
    CASE department
        WHEN 'IT'      THEN 'Information Technology'
        WHEN 'HR'      THEN 'Human Resources'
        WHEN 'Finance' THEN 'Finance & Accounting'
        ELSE                'Other'
    END AS department_full
FROM sample_data;

-------------------------------------------------
-- Region: 3. COALESCE
-------------------------------------------------
/*
  3.1 Return the first non-NULL value from a list.
       Here salary defaults to 0 when not set.
*/
SELECT
    name,
    COALESCE(salary, 0.00) AS effective_salary
FROM sample_data;

/*
  3.2 Concatenate optional fields, skipping NULLs.
*/
SELECT
    name,
    COALESCE(
        CONCAT(department, ' – salary: ', salary),
        CONCAT(department, ' – salary: not provided')
    ) AS summary
FROM sample_data;

-------------------------------------------------
-- Region: 4. NULLIF
-------------------------------------------------
/*
  4.1 NULLIF(a, b) returns NULL when a = b.
       Classic use: prevent division by zero.
*/
DROP TABLE IF EXISTS sales_data;

CREATE TABLE sales_data
(
    product  VARCHAR(100) NOT NULL,
    units_sold INT        NOT NULL DEFAULT 0,
    revenue  DECIMAL(10,2) NOT NULL DEFAULT 0
) ENGINE = InnoDB;

INSERT INTO sales_data (product, units_sold, revenue)
VALUES
    ('Widget A', 100, 5000.00),
    ('Widget B',   0,    0.00),
    ('Widget C',  50, 2500.00);

SELECT
    product,
    units_sold,
    revenue,
    revenue / NULLIF(units_sold, 0) AS avg_price_per_unit
FROM sales_data;

/*
  4.2 Suppress a sentinel string and treat it as NULL.
*/
SELECT
    name,
    NULLIF(department, 'Finance') AS dept_no_finance
FROM sample_data;

-------------------------------------------------
-- Region: 5. IFNULL and IF (MySQL Shorthand)
-------------------------------------------------
/*
  5.1 IFNULL is equivalent to COALESCE with two arguments.
*/
SELECT
    name,
    IFNULL(salary, 0.00) AS effective_salary
FROM sample_data;

/*
  5.2 IF(condition, true_value, false_value) is a compact alternative
       to a two-branch CASE expression.
*/
SELECT
    name,
    IF(salary IS NULL, 'Unset', FORMAT(salary, 2)) AS salary_display
FROM sample_data;

-------------------------------------------------
-- Region: 6. CONVERT_TZ (AT TIME ZONE Equivalent)
-------------------------------------------------
/*
  6.1 MySQL uses CONVERT_TZ instead of the AT TIME ZONE syntax.
       Requires the time zone tables to be populated
       (mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql).
*/
SELECT
    name,
    NOW()                                          AS server_time,
    CONVERT_TZ(NOW(), @@global.time_zone, 'UTC')   AS utc_time,
    CONVERT_TZ(NOW(), @@global.time_zone, 'US/Pacific') AS pacific_time
FROM sample_data
LIMIT 1;

-------------------------------------------------
-- Region: 7. Optimizer Hints
-------------------------------------------------
/*
  7.1 MySQL 8.0 supports inline optimizer hints in SQL comments.
       Use /*+ ... */ immediately after SELECT/UPDATE/DELETE/INSERT.

   Common hints:
     NO_INDEX(tbl, idx)    force the optimizer to skip an index
     INDEX(tbl, idx)       suggest using a specific index
     SET_VAR(var=val)      set a session variable for one statement
     MAX_EXECUTION_TIME(ms) cap query execution time
*/
SELECT /*+ MAX_EXECUTION_TIME(1000) */
    name, salary
FROM sample_data
WHERE department = 'IT';

/*
  7.2 STRAIGHT_JOIN fixes the join order to left-to-right (like FORCE ORDER).
*/
SELECT STRAIGHT_JOIN
    s.name,
    s.department
FROM sample_data s
JOIN sample_data s2 ON s.id = s2.id
WHERE s.department = 'IT';

-------------------------------------------------
-- Region: 8. LAST_INSERT_ID (OUTPUT Equivalent)
-------------------------------------------------
/*
  8.1 After an INSERT, LAST_INSERT_ID() returns the AUTO_INCREMENT
       value for the row just inserted — the closest MySQL equivalent
       to the SQL Server OUTPUT clause for capturing generated keys.
*/
INSERT INTO sample_data (name, age, salary, department, notes)
VALUES ('Frank', 32, 70000.00, 'Marketing', 'Inserted by example');

SELECT LAST_INSERT_ID() AS newly_inserted_id;

/*
  8.2 For multi-row inserts LAST_INSERT_ID() returns the id of the
       first inserted row in the batch.
*/
INSERT INTO sample_data (name, age, salary, department, notes)
VALUES
    ('Grace',  29, 65000.00, 'Marketing', NULL),
    ('Henry',  45, 95000.00, 'Finance',   NULL);

SELECT LAST_INSERT_ID() AS first_id_of_batch;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
