/**************************************************************
 * MySQL 8.0 CTE (Common Table Expressions) Tutorial
 * This script demonstrates CTE techniques in MySQL
 * 8.0, including:
 * - Simple (non-recursive) CTEs.
 * - Chained / nested CTEs.
 * - Recursive CTEs for hierarchical traversal.
 * - CTE used inside UPDATE and DELETE.
 * - CTE for pagination helpers.
 * - Mutual recursion (simulated with a limit guard).
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

CREATE TABLE departments
(
    dept_id   INT         PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(60) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE employees
(
    employee_id   INT           PRIMARY KEY AUTO_INCREMENT,
    employee_name VARCHAR(100)  NOT NULL,
    dept_id       INT,
    manager_id    INT,
    salary        DECIMAL(10,2) NOT NULL,
    hire_date     DATE          NOT NULL,
    CONSTRAINT fk_emp_dept    FOREIGN KEY (dept_id)    REFERENCES departments (dept_id),
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees   (employee_id)
) ENGINE = InnoDB;

INSERT INTO departments (dept_id, dept_name)
VALUES (1,'Engineering'),(2,'Marketing'),(3,'Finance'),(4,'HR');

INSERT INTO employees (employee_id, employee_name, dept_id, manager_id, salary, hire_date)
VALUES
    ( 1, 'CEO',          NULL, NULL, 200000, '2010-01-01'),
    ( 2, 'CTO',          1,    1,    150000, '2012-03-15'),
    ( 3, 'CFO',          3,    1,    140000, '2013-06-01'),
    ( 4, 'CMO',          2,    1,    130000, '2014-09-10'),
    ( 5, 'Dev Lead',     1,    2,    110000, '2015-02-20'),
    ( 6, 'Developer 1',  1,    5,     85000, '2017-07-11'),
    ( 7, 'Developer 2',  1,    5,     82000, '2018-01-30'),
    ( 8, 'Analyst',      3,    3,     75000, '2016-11-05'),
    ( 9, 'HR Manager',   4,    1,     90000, '2015-08-22'),
    (10, 'Recruiter',    4,    9,     65000, '2019-04-03');

-------------------------------------------------
-- Region: 1. Simple CTE
-------------------------------------------------
/*
  1.1 Filter IT employees using a CTE.
*/
WITH engineering_cte AS
(
    SELECT e.employee_id, e.employee_name, e.salary
    FROM employees  e
    JOIN departments d ON e.dept_id = d.dept_id
    WHERE d.dept_name = 'Engineering'
)
SELECT *
FROM engineering_cte;

-------------------------------------------------
-- Region: 2. Chained CTEs
-------------------------------------------------
/*
  2.1 Build two CTEs sequentially: the second references the first.
*/
WITH dept_avg AS
(
    SELECT dept_id,
           AVG(salary) AS avg_salary
    FROM employees
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
),
above_avg AS
(
    SELECT e.employee_name,
           e.salary,
           d.avg_salary,
           ROUND(e.salary - d.avg_salary, 2) AS diff_from_avg
    FROM employees e
    JOIN dept_avg  d ON e.dept_id = d.dept_id
    WHERE e.salary > d.avg_salary
)
SELECT *
FROM above_avg
ORDER BY diff_from_avg DESC;

-------------------------------------------------
-- Region: 3. Recursive CTE – Organisational Hierarchy
-------------------------------------------------
/*
  3.1 Walk the management chain from the CEO downward.
       The anchor selects top-level employees (no manager);
       the recursive member adds direct reports level by level.
*/
WITH RECURSIVE org_hierarchy
(
    employee_id,
    manager_id,
    employee_name,
    level,
    path
) AS
(
    -- Anchor: top-level (CEO)
    SELECT employee_id,
           manager_id,
           employee_name,
           1                              AS level,
           CAST(employee_name AS CHAR(500)) AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: direct reports
    SELECT e.employee_id,
           e.manager_id,
           e.employee_name,
           h.level + 1,
           CONCAT(h.path, ' → ', e.employee_name)
    FROM employees e
    JOIN org_hierarchy h ON e.manager_id = h.employee_id
)
SELECT
    employee_id,
    manager_id,
    CONCAT(REPEAT('  ', level - 1), employee_name) AS indented_name,
    level,
    path
FROM org_hierarchy
ORDER BY path;

/*
  3.2 Find everyone who reports (directly or indirectly) to the CTO (employee_id = 2).
*/
WITH RECURSIVE reports_to_cto AS
(
    SELECT employee_id, employee_name, manager_id
    FROM employees
    WHERE employee_id = 2       -- CTO is the anchor

    UNION ALL

    SELECT e.employee_id, e.employee_name, e.manager_id
    FROM employees e
    JOIN reports_to_cto r ON e.manager_id = r.employee_id
)
SELECT employee_id, employee_name
FROM reports_to_cto
WHERE employee_id <> 2          -- exclude the CTO himself
ORDER BY employee_id;

-------------------------------------------------
-- Region: 4. CTE inside UPDATE
-------------------------------------------------
/*
  4.1 Give a 5 % bonus to all employees two levels below the CEO.
       The CTE identifies targets; UPDATE references the CTE.
      (MySQL requires wrapping the CTE as a subquery in the FROM clause
       of a multi-table UPDATE.)
*/
WITH RECURSIVE level_two AS
(
    SELECT employee_id, 1 AS lvl
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, l.lvl + 1
    FROM employees e
    JOIN level_two l ON e.manager_id = l.employee_id
    WHERE l.lvl < 2
)
UPDATE employees e
JOIN   level_two l ON e.employee_id = l.employee_id
SET    e.salary = e.salary * 1.05
WHERE  l.lvl = 2;

SELECT employee_id, employee_name, salary
FROM employees
WHERE manager_id = 1;

-------------------------------------------------
-- Region: 5. CTE inside DELETE
-------------------------------------------------
/*
  5.1 Delete employees hired before 2016 who earn less than the
       department average (demonstration only – roll back after).
*/
START TRANSACTION;

WITH dept_avg AS
(
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
)
DELETE e
FROM employees e
JOIN  dept_avg d ON e.dept_id = d.dept_id
WHERE e.hire_date < '2016-01-01'
  AND e.salary    < d.avg_salary;

SELECT employee_id, employee_name FROM employees ORDER BY employee_id;

ROLLBACK;   -- restore original data

-------------------------------------------------
-- Region: 6. CTE for Pagination
-------------------------------------------------
/*
  6.1 Add a dense row number and slice by page.
       ROW_NUMBER() inside a CTE is a cleaner alternative to
       convoluted subqueries.
*/
WITH ranked AS
(
    SELECT employee_id,
           employee_name,
           salary,
           ROW_NUMBER() OVER (ORDER BY salary DESC) AS rn
    FROM employees
)
SELECT employee_id, employee_name, salary
FROM ranked
WHERE rn BETWEEN 3 AND 5;   -- page 2 (rows 3-5 by highest salary)

-------------------------------------------------
-- Region: 7. Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
