/**************************************************************
 * MySQL 8.0 Window Functions Tutorial
 * Description: This script demonstrates ranking, navigation,
 *              distribution, and aggregate window functions in
 *              MySQL 8.0, along with a median pattern built from
 *              row numbers when percentile functions are not
 *              available.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS sales;

CREATE TABLE sales
(
    sale_id INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    customer_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO sales (sale_id, sale_date, customer_id, amount)
VALUES
    (1, '2023-01-01', 1, 100.00),
    (2, '2023-01-02', 2, 150.00),
    (3, '2023-01-03', 1, 200.00),
    (4, '2023-01-04', 3, 250.00),
    (5, '2023-01-05', 2, 300.00);

-------------------------------------------------
-- Region: 1. Ranking Functions
-------------------------------------------------
SELECT
    sale_id,
    sale_date,
    customer_id,
    amount,
    ROW_NUMBER() OVER (ORDER BY sale_date) AS row_num
FROM sales;

SELECT
    sale_id,
    sale_date,
    customer_id,
    amount,
    RANK() OVER (ORDER BY amount DESC) AS rank_value,
    DENSE_RANK() OVER (ORDER BY amount DESC) AS dense_rank_value,
    NTILE(3) OVER (ORDER BY amount DESC) AS ntile_value
FROM sales;

-------------------------------------------------
-- Region: 2. Navigation Functions
-------------------------------------------------
SELECT
    sale_id,
    sale_date,
    customer_id,
    amount,
    LAG(amount, 1, 0) OVER (ORDER BY sale_date) AS previous_amount,
    LEAD(amount, 1, 0) OVER (ORDER BY sale_date) AS next_amount,
    FIRST_VALUE(amount) OVER (ORDER BY sale_date) AS first_amount,
    LAST_VALUE(amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_amount
FROM sales;

-------------------------------------------------
-- Region: 3. Distribution Functions
-------------------------------------------------
SELECT
    sale_id,
    amount,
    CUME_DIST() OVER (ORDER BY amount DESC) AS cume_dist_value,
    PERCENT_RANK() OVER (ORDER BY amount DESC) AS percent_rank_value
FROM sales;

-------------------------------------------------
-- Region: 4. Aggregate Window Functions
-------------------------------------------------
SELECT
    sale_id,
    sale_date,
    customer_id,
    amount,
    SUM(amount) OVER (PARTITION BY customer_id ORDER BY sale_date) AS running_total,
    AVG(amount) OVER (PARTITION BY customer_id ORDER BY sale_date) AS running_average,
    COUNT(*) OVER (PARTITION BY customer_id ORDER BY sale_date) AS running_count,
    MAX(amount) OVER (PARTITION BY customer_id ORDER BY sale_date) AS running_max,
    MIN(amount) OVER (PARTITION BY customer_id ORDER BY sale_date) AS running_min
FROM sales;

-------------------------------------------------
-- Region: 5. Median Pattern Without PERCENTILE_CONT
-------------------------------------------------
WITH ordered_sales AS
(
    SELECT
        amount,
        ROW_NUMBER() OVER (ORDER BY amount) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM sales
)
SELECT AVG(amount) AS median_amount
FROM ordered_sales
WHERE row_num IN (
    FLOOR((total_rows + 1) / 2),
    FLOOR((total_rows + 2) / 2)
);

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------