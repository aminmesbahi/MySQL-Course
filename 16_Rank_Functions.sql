/**************************************************************
 * MySQL 8.0 Rank Functions Tutorial
 * Description: This script demonstrates the use of ranking
 *              functions in MySQL 8.0, including:
 *              - RANK(), DENSE_RANK(), NTILE(), and ROW_NUMBER()
 *              - Ranking within partitions
 *              - Top-N filtering patterns using Common Table
 *                Expressions (CTEs)
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS employees;

CREATE TABLE employees
(
    employee_id INT PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO employees (employee_id, employee_name, department, salary)
VALUES
    (1, 'Alice', 'HR', 60000.00),
    (2, 'Bob', 'IT', 80000.00),
    (3, 'Charlie', 'HR', 70000.00),
    (4, 'David', 'IT', 90000.00),
    (5, 'Eve', 'Finance', 75000.00),
    (6, 'Farah', 'Finance', 75000.00),
    (7, 'Hadi', 'IT', 80000.00);

-------------------------------------------------
-- Region: 1. Basic Ranking Functions
-------------------------------------------------
/*
  1.1 RANK() assigns the same rank to ties and leaves gaps.
*/
SELECT
    employee_id,
    employee_name,
    department,
    salary,
    RANK() OVER (ORDER BY salary DESC) AS rank_value
FROM employees;

/*
  1.2 DENSE_RANK() assigns the same rank to ties without gaps.
*/
SELECT
    employee_id,
    employee_name,
    department,
    salary,
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank_value
FROM employees;

/*
  1.3 NTILE() distributes rows into equal-sized groups.
*/
SELECT
    employee_id,
    employee_name,
    department,
    salary,
    NTILE(3) OVER (ORDER BY salary DESC) AS ntile_value
FROM employees;

/*
  1.4 ROW_NUMBER() gives each row a unique sequence number.
*/
SELECT
    employee_id,
    employee_name,
    department,
    salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC) AS row_num
FROM employees;

-------------------------------------------------
-- Region: 2. Ranking Inside Partitions
-------------------------------------------------
/*
  2.1 Rank salaries inside each department.
*/
SELECT
    employee_id,
    employee_name,
    department,
    salary,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS department_rank,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS department_dense_rank,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, employee_id) AS department_row_num
FROM employees;

-------------------------------------------------
-- Region: 3. Top-N Patterns
-------------------------------------------------
/*
  3.1 Return the top 2 salaries in each department using RANK().
*/
WITH ranked_employees AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        salary,
        RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS department_rank
    FROM employees
)
SELECT *
FROM ranked_employees
WHERE department_rank <= 2;

/*
  3.2 Return the top 2 rows in each department using ROW_NUMBER().
*/
WITH numbered_employees AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, employee_id) AS department_row_num
    FROM employees
)
SELECT *
FROM numbered_employees
WHERE department_row_num <= 2;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------