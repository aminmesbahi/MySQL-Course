/**************************************************************
 * MySQL 8.0 Cursor Tutorial
 * This script demonstrates various cursor techniques
 * in MySQL 8.0, including:
 * - Basic DECLARE / OPEN / FETCH / CLOSE cursors.
 * - NOT FOUND handler to detect end-of-cursor.
 * - Updating rows via a cursor loop.
 * - Nested cursors.
 * - Cursor-based report generation into a staging table.
 *
 *  NOTE: Cursors in MySQL exist only inside stored routines.
 *        All examples are wrapped in stored procedures.
 *        Set-based alternatives are always preferable for performance;
 *        use cursors only when row-by-row processing is unavoidable.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization and Sample Data
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS salary_report;

CREATE TABLE employees
(
    employee_id INT          PRIMARY KEY AUTO_INCREMENT,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    department  VARCHAR(60)  NOT NULL,
    salary      DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO employees (first_name, last_name, department, salary)
VALUES
    ('John',  'Doe',     'Engineering', 75000),
    ('Jane',  'Smith',   'Marketing',   65000),
    ('Bob',   'Johnson', 'Engineering', 80000),
    ('Alice', 'Brown',   'Finance',     72000),
    ('Carol', 'Wilson',  'Marketing',   68000);

CREATE TABLE products
(
    product_id   INT          PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(60)  NOT NULL,
    list_price   DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO products (product_name, category, list_price)
VALUES
    ('Widget Pro',    'Widgets',    49.99),
    ('Widget Basic',  'Widgets',    19.99),
    ('Gadget Plus',   'Gadgets',    99.99),
    ('Gadget Lite',   'Gadgets',    39.99),
    ('Gizmo X',       'Gizmos',     59.99);

CREATE TABLE salary_report
(
    report_id   INT          PRIMARY KEY AUTO_INCREMENT,
    employee_id INT          NOT NULL,
    full_name   VARCHAR(100) NOT NULL,
    department  VARCHAR(60)  NOT NULL,
    salary      DECIMAL(10,2) NOT NULL,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 1. Basic Cursor
-------------------------------------------------
/*
  1.1 Iterate over all employees and print their details using SELECT.
       NOT FOUND handler flips the 'done' flag when FETCH exhausts the result set.
*/
DROP PROCEDURE IF EXISTS BasicCursorDemo;

DELIMITER //

CREATE PROCEDURE BasicCursorDemo()
BEGIN
    DECLARE v_done       INT           DEFAULT FALSE;
    DECLARE v_emp_id     INT;
    DECLARE v_first      VARCHAR(50);
    DECLARE v_last       VARCHAR(50);

    DECLARE emp_cursor CURSOR FOR
        SELECT employee_id, first_name, last_name
        FROM employees;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN emp_cursor;

    read_loop: LOOP
        FETCH emp_cursor INTO v_emp_id, v_first, v_last;
        IF v_done THEN
            LEAVE read_loop;
        END IF;

        -- Row-by-row processing: here we simply SELECT each row
        SELECT v_emp_id   AS employee_id,
               v_first    AS first_name,
               v_last     AS last_name;
    END LOOP;

    CLOSE emp_cursor;
END //

DELIMITER ;

CALL BasicCursorDemo();

-------------------------------------------------
-- Region: 2. Cursor with Row Update
-------------------------------------------------
/*
  2.1 Give a 10 % pay rise to all employees whose list price (salary) is below $75 000.
       Demonstrates using a cursor to drive UPDATE statements.
*/
DROP PROCEDURE IF EXISTS RaiseSalaries;

DELIMITER //

CREATE PROCEDURE RaiseSalaries(IN p_threshold DECIMAL(10,2))
BEGIN
    DECLARE v_done   INT    DEFAULT FALSE;
    DECLARE v_emp_id INT;
    DECLARE v_salary DECIMAL(10,2);

    DECLARE salary_cursor CURSOR FOR
        SELECT employee_id, salary
        FROM employees
        WHERE salary < p_threshold;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN salary_cursor;

    update_loop: LOOP
        FETCH salary_cursor INTO v_emp_id, v_salary;
        IF v_done THEN
            LEAVE update_loop;
        END IF;

        UPDATE employees
        SET salary = salary * 1.10
        WHERE employee_id = v_emp_id;
    END LOOP;

    CLOSE salary_cursor;
END //

DELIMITER ;

CALL RaiseSalaries(75000.00);

SELECT employee_id, first_name, last_name, salary
FROM employees
ORDER BY employee_id;

-------------------------------------------------
-- Region: 3. Cursor-Based Report Generation
-------------------------------------------------
/*
  3.1 Populate a salary_report staging table by iterating over employees.
       In production, a single INSERT … SELECT would be faster;
       the cursor approach is shown for instructional completeness.
*/
DROP PROCEDURE IF EXISTS GenerateSalaryReport;

DELIMITER //

CREATE PROCEDURE GenerateSalaryReport()
BEGIN
    DECLARE v_done       INT           DEFAULT FALSE;
    DECLARE v_emp_id     INT;
    DECLARE v_first      VARCHAR(50);
    DECLARE v_last       VARCHAR(50);
    DECLARE v_dept       VARCHAR(60);
    DECLARE v_salary     DECIMAL(10,2);

    DECLARE rpt_cursor CURSOR FOR
        SELECT employee_id, first_name, last_name, department, salary
        FROM employees
        ORDER BY department, last_name;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    TRUNCATE TABLE salary_report;

    OPEN rpt_cursor;

    rpt_loop: LOOP
        FETCH rpt_cursor INTO v_emp_id, v_first, v_last, v_dept, v_salary;
        IF v_done THEN
            LEAVE rpt_loop;
        END IF;

        INSERT INTO salary_report (employee_id, full_name, department, salary)
        VALUES (v_emp_id, CONCAT(v_first, ' ', v_last), v_dept, v_salary);
    END LOOP;

    CLOSE rpt_cursor;

    SELECT * FROM salary_report ORDER BY department, full_name;
END //

DELIMITER ;

CALL GenerateSalaryReport();

-------------------------------------------------
-- Region: 4. Nested Cursors
-------------------------------------------------
/*
  4.1 For each department, iterate over its employees.
       Demonstrates two concurrently open cursors.
       Note: MySQL requires all DECLARE statements before any other statements
       in a BEGIN…END block – nested BEGIN…END blocks allow a second set of
       DECLAREs.
*/
DROP PROCEDURE IF EXISTS NestedCursorDemo;

DELIMITER //

CREATE PROCEDURE NestedCursorDemo()
BEGIN
    -- Outer cursor variables
    DECLARE v_outer_done INT DEFAULT FALSE;
    DECLARE v_dept       VARCHAR(60);

    -- Inner cursor variables
    DECLARE v_inner_done INT DEFAULT FALSE;
    DECLARE v_emp_id     INT;
    DECLARE v_full_name  VARCHAR(100);
    DECLARE v_salary     DECIMAL(10,2);

    DECLARE dept_cursor CURSOR FOR
        SELECT DISTINCT department FROM employees ORDER BY department;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_outer_done = TRUE;

    OPEN dept_cursor;

    dept_loop: LOOP
        FETCH dept_cursor INTO v_dept;
        IF v_outer_done THEN
            LEAVE dept_loop;
        END IF;

        SELECT CONCAT('=== Department: ', v_dept, ' ===') AS header;

        -- Inner block with its own cursor and NOT FOUND handler
        BEGIN
            DECLARE emp_cursor CURSOR FOR
                SELECT employee_id,
                       CONCAT(first_name, ' ', last_name),
                       salary
                FROM employees
                WHERE department = v_dept
                ORDER BY salary DESC;

            DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_inner_done = TRUE;

            SET v_inner_done = FALSE;   -- reset for each department

            OPEN emp_cursor;

            emp_loop: LOOP
                FETCH emp_cursor INTO v_emp_id, v_full_name, v_salary;
                IF v_inner_done THEN
                    LEAVE emp_loop;
                END IF;

                SELECT v_emp_id   AS employee_id,
                       v_full_name AS full_name,
                       v_salary   AS salary;
            END LOOP;

            CLOSE emp_cursor;
        END;
    END LOOP;

    CLOSE dept_cursor;
END //

DELIMITER ;

CALL NestedCursorDemo();

-------------------------------------------------
-- Region: 5. Cursor Pattern: Accumulate a Running Total
-------------------------------------------------
/*
  5.1 Compute a running salary total per department – illustrates
      accumulation patterns.  A window SUM() OVER () is
      the set-based equivalent (see lesson 15).
*/
DROP PROCEDURE IF EXISTS RunningSalaryTotal;

DELIMITER //

CREATE PROCEDURE RunningSalaryTotal()
BEGIN
    DECLARE v_done       INT           DEFAULT FALSE;
    DECLARE v_dept       VARCHAR(60);
    DECLARE v_emp_name   VARCHAR(100);
    DECLARE v_salary     DECIMAL(10,2);
    DECLARE v_running    DECIMAL(12,2) DEFAULT 0;
    DECLARE v_prev_dept  VARCHAR(60)   DEFAULT '';

    DECLARE sal_cursor CURSOR FOR
        SELECT department,
               CONCAT(first_name, ' ', last_name),
               salary
        FROM employees
        ORDER BY department, salary DESC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    CREATE TEMPORARY TABLE IF NOT EXISTS running_totals
    (
        department   VARCHAR(60),
        employee     VARCHAR(100),
        salary       DECIMAL(10,2),
        running_total DECIMAL(12,2)
    );

    TRUNCATE TABLE running_totals;

    OPEN sal_cursor;

    fetch_loop: LOOP
        FETCH sal_cursor INTO v_dept, v_emp_name, v_salary;
        IF v_done THEN
            LEAVE fetch_loop;
        END IF;

        IF v_dept <> v_prev_dept THEN
            SET v_running = 0;
            SET v_prev_dept = v_dept;
        END IF;

        SET v_running = v_running + v_salary;

        INSERT INTO running_totals VALUES (v_dept, v_emp_name, v_salary, v_running);
    END LOOP;

    CLOSE sal_cursor;

    SELECT * FROM running_totals ORDER BY department, salary DESC;

    DROP TEMPORARY TABLE IF EXISTS running_totals;
END //

DELIMITER ;

CALL RunningSalaryTotal();

-------------------------------------------------
-- Region: 6. Cleanup
-------------------------------------------------
DROP PROCEDURE IF EXISTS BasicCursorDemo;
DROP PROCEDURE IF EXISTS RaiseSalaries;
DROP PROCEDURE IF EXISTS GenerateSalaryReport;
DROP PROCEDURE IF EXISTS NestedCursorDemo;
DROP PROCEDURE IF EXISTS RunningSalaryTotal;
DROP TABLE    IF EXISTS salary_report;
DROP TABLE    IF EXISTS products;
DROP TABLE    IF EXISTS employees;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
