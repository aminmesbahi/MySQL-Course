/**************************************************************
 * MySQL 8.0 Basic Concepts Tutorial
 * This script demonstrates fundamental MySQL 8.0
 * concepts and patterns, including:
 * - Table creation, data insertion, and cleanup.
 * - Datetime with time-zone conversion (CONVERT_TZ).
 * - Optimizer hints (MAX_EXECUTION_TIME, NO_INDEX).
 * - Row value constructors and INSERT … SELECT.
 * - LIMIT / OFFSET for top-N patterns.
 * - Common Table Expressions (CTEs) and nested CTEs.
 * - SIGNAL for application-defined errors.
 * - VALUES row constructor (MySQL 8.0.19+).
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS sample_data;

CREATE TABLE sample_data
(
    id         INT            PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100)   NOT NULL,
    age        INT            NOT NULL,
    salary     DECIMAL(10,2),
    department VARCHAR(100)   NOT NULL,
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
-- Region: 1. Datetime and Time Zone Conversion
-------------------------------------------------
/*
  1.1 MySQL uses CONVERT_TZ instead of the AT TIME ZONE clause.
       The time zone tables must be populated first:
         mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
*/
SELECT
    name,
    NOW()                                                 AS server_time,
    CONVERT_TZ(NOW(), @@global.time_zone, 'UTC')          AS utc_time,
    CONVERT_TZ(NOW(), @@global.time_zone, 'US/Pacific')   AS pst_time,
    DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s')               AS formatted_time
FROM sample_data
LIMIT 1;

-------------------------------------------------
-- Region: 2. Optimizer Hints
-------------------------------------------------
/*
  2.1 MAX_EXECUTION_TIME caps runtime in milliseconds (session hint).
*/
SELECT /*+ MAX_EXECUTION_TIME(2000) */
    name,
    salary
FROM sample_data
WHERE department = 'IT';

/*
  2.2 NO_INDEX prevents the optimizer from using a specific index.
*/
SELECT /*+ NO_INDEX(sample_data PRIMARY) */
    id, name
FROM sample_data
WHERE id = 3;

/*
  2.3 SET_VAR changes a session variable for the duration of one statement.
*/
SELECT /*+ SET_VAR(sort_buffer_size = 1048576) */
    name, age
FROM sample_data
ORDER BY age DESC;

-------------------------------------------------
-- Region: 3. LAST_INSERT_ID (OUTPUT Clause Equivalent)
-------------------------------------------------
/*
  3.1 Capture the auto-generated primary key after an INSERT.
*/
INSERT INTO sample_data (name, age, salary, department, notes)
VALUES ('Frank', 32, 70000.00, 'Marketing', 'Inserted by example');

SELECT LAST_INSERT_ID() AS newly_inserted_id;

-------------------------------------------------
-- Region: 4. Row Value Constructors
-------------------------------------------------
/*
  4.1 Table value constructor (VALUES row constructor, MySQL 8.0.19+).
       Works as a derived table: VALUES ROW(…), ROW(…) …
*/
SELECT *
FROM (VALUES ROW(1, 'Engineering'), ROW(2, 'Operations'), ROW(3, 'Legal'))
     AS dept_map(dept_id, dept_name);

/*
  4.2 INSERT with a VALUES row constructor.
*/
INSERT INTO sample_data (name, age, salary, department, notes)
VALUES
    ROW('Grace', 29, 65000.00, 'Marketing', NULL),
    ROW('Henry', 45, 95000.00, 'Finance',   NULL);

-------------------------------------------------
-- Region: 5. LIMIT / OFFSET
-------------------------------------------------
/*
  5.1 Top-3 highest-paid employees.
*/
SELECT name, salary
FROM sample_data
ORDER BY COALESCE(salary, 0) DESC
LIMIT 3;

/*
  5.2 Paginate: second page of 3 rows.
*/
SELECT name, salary
FROM sample_data
ORDER BY id
LIMIT 3 OFFSET 3;

-------------------------------------------------
-- Region: 6. Common Table Expressions (CTEs)
-------------------------------------------------
/*
  6.1 Simple CTE: filter IT employees.
*/
WITH it_employees AS
(
    SELECT name, salary
    FROM sample_data
    WHERE department = 'IT'
)
SELECT *
FROM it_employees;

/*
  6.2 Nested / chained CTEs.
*/
WITH dept_it AS
(
    SELECT name, salary
    FROM sample_data
    WHERE department = 'IT'
),
high_earners AS
(
    SELECT name, salary
    FROM dept_it
    WHERE salary > 80000
)
SELECT * FROM high_earners;

/*
  6.3 Recursive CTE – organisational hierarchy.
*/
DROP TABLE IF EXISTS org_chart;

CREATE TABLE org_chart
(
    employee_id   INT         PRIMARY KEY AUTO_INCREMENT,
    employee_name VARCHAR(100) NOT NULL,
    manager_id    INT
) ENGINE = InnoDB;

INSERT INTO org_chart (employee_id, employee_name, manager_id)
VALUES
    (1, 'CEO',     NULL),
    (2, 'CTO',     1),
    (3, 'CFO',     1),
    (4, 'Dev Lead', 2),
    (5, 'Dev 1',   4),
    (6, 'Dev 2',   4),
    (7, 'Analyst', 3);

WITH RECURSIVE org_cte (employee_id, manager_id, employee_name, level) AS
(
    -- Anchor: top-level employees (no manager)
    SELECT employee_id, manager_id, employee_name, 1 AS level
    FROM org_chart
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: employees with a manager
    SELECT e.employee_id, e.manager_id, e.employee_name,
           cte.level + 1
    FROM org_chart e
    JOIN org_cte cte ON e.manager_id = cte.employee_id
)
SELECT
    employee_id,
    manager_id,
    CONCAT(REPEAT('  ', level - 1), employee_name) AS indented_name,
    level
FROM org_cte
ORDER BY level, employee_id;

-------------------------------------------------
-- Region: 7. SIGNAL – Application-Defined Errors
-------------------------------------------------
/*
  7.1 SIGNAL raises a custom error condition in a stored routine
       or trigger – the MySQL equivalent of RAISERROR / THROW.
*/
DROP PROCEDURE IF EXISTS ValidateSalary;

DELIMITER //

CREATE PROCEDURE ValidateSalary(IN p_salary DECIMAL(10,2))
BEGIN
    IF p_salary < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary cannot be negative.',
                MYSQL_ERRNO   = 1001;
    END IF;

    -- Proceed with insertion if valid
    INSERT INTO sample_data (name, age, salary, department)
    VALUES ('Test', 30, p_salary, 'IT');
END //

DELIMITER ;

-- 7.2 Valid call:
CALL ValidateSalary(55000.00);

-- 7.3 Invalid call (triggers SIGNAL):
-- CALL ValidateSalary(-100.00);

-------------------------------------------------
-- Region: 8. Search Conditions (WHERE Patterns)
-------------------------------------------------
/*
  8.1 Composite condition using AND / OR / NOT with proper parentheses.
*/
SELECT name, age, salary, department
FROM sample_data
WHERE department IN ('IT', 'HR')
  AND (salary IS NOT NULL OR age < 30);

/*
  8.2 BETWEEN for range checks.
*/
SELECT name, age
FROM sample_data
WHERE age BETWEEN 28 AND 35;

/*
  8.3 LIKE pattern matching.
*/
SELECT name
FROM sample_data
WHERE name LIKE '%a%';

/*
  8.4 REGEXP pattern matching.
*/
SELECT name
FROM sample_data
WHERE name REGEXP '^[A-E]';

-------------------------------------------------
-- Region: 9. Cleanup
-------------------------------------------------
DROP PROCEDURE IF EXISTS ValidateSalary;
DROP TABLE    IF EXISTS org_chart;
DROP TABLE    IF EXISTS sample_data;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
