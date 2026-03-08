/**************************************************************
 * MySQL 8.0 Distribution Analytics Tutorial
 * Description: This script demonstrates MySQL-friendly
 *              alternatives to SQL Server approximate percentile
 *              features. It covers:
 *              - Exact percentile-style queries using CUME_DIST()
 *              - Distribution buckets and histograms
 *              - Coarser rounded summaries as practical
 *                approximation patterns
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS sales_distribution;

CREATE TABLE sales_distribution
(
    sale_id INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    customer_id INT NOT NULL,
    amount DECIMAL(10, 2) NULL,
    region_id INT NOT NULL
) ENGINE = InnoDB;

INSERT INTO sales_distribution (sale_id, sale_date, customer_id, amount, region_id)
VALUES
    (1, '2023-01-01', 1, 120.00, 1),
    (2, '2023-01-02', 1, 180.00, 1),
    (3, '2023-01-03', 1, 240.00, 2),
    (4, '2023-01-04', 2, 95.00, 1),
    (5, '2023-01-05', 2, 210.00, 2),
    (6, '2023-01-06', 2, 320.00, 2),
    (7, '2023-01-07', 3, 140.00, 3),
    (8, '2023-01-08', 3, 155.00, 3),
    (9, '2023-01-09', 3, 410.00, 1),
    (10, '2023-01-10', 4, NULL, 1),
    (11, '2023-01-11', 4, 260.00, 2),
    (12, '2023-01-12', 4, 280.00, 2);

-------------------------------------------------
-- Region: 1. Exact P50 and P95 Style Queries
-------------------------------------------------
/*
  1.1 Compute the first value at or above the target percentile.
*/
WITH ordered_sales AS
(
    SELECT
        customer_id,
        amount,
        CUME_DIST() OVER (PARTITION BY customer_id ORDER BY amount) AS cume_dist_value
    FROM sales_distribution
    WHERE amount IS NOT NULL
)
SELECT
    customer_id,
    MIN(CASE WHEN cume_dist_value >= 0.50 THEN amount END) AS p50_amount,
    MIN(CASE WHEN cume_dist_value >= 0.95 THEN amount END) AS p95_amount
FROM ordered_sales
GROUP BY customer_id;

-------------------------------------------------
-- Region: 2. Histogram Buckets
-------------------------------------------------
/*
  2.1 Group amounts into 100-unit buckets.
*/
SELECT
    FLOOR(amount / 100) * 100 AS bucket_start,
    FLOOR(amount / 100) * 100 + 99.99 AS bucket_end,
    COUNT(*) AS sale_count,
    AVG(amount) AS avg_amount
FROM sales_distribution
WHERE amount IS NOT NULL
GROUP BY FLOOR(amount / 100)
ORDER BY bucket_start;

-------------------------------------------------
-- Region: 3. Coarser Rounded Summaries
-------------------------------------------------
/*
  3.1 Rounding values can be useful when the goal is quick
      directional analysis rather than exact precision.
*/
SELECT
    customer_id,
    ROUND(AVG(amount), -1) AS rounded_avg_amount,
    ROUND(MAX(amount), -1) AS rounded_max_amount
FROM sales_distribution
WHERE amount IS NOT NULL
GROUP BY customer_id;

-------------------------------------------------
-- Region: 4. Regional Distribution Review
-------------------------------------------------
/*
  4.1 Use NTILE() to divide values into quartiles inside regions.
*/
WITH regional_distribution AS
(
    SELECT
        sale_id,
        region_id,
        amount,
        NTILE(4) OVER (PARTITION BY region_id ORDER BY amount) AS quartile_group
    FROM sales_distribution
    WHERE amount IS NOT NULL
)
SELECT *
FROM regional_distribution
ORDER BY region_id, quartile_group, amount;

-------------------------------------------------
-- Region: 5. Notes
-------------------------------------------------
/*
  5.1 MySQL does not currently provide APPROX_PERCENTILE_CONT() or
      APPROX_PERCENTILE_DISC(). Use exact window-function patterns,
      histograms, rounded summaries, or pre-aggregated tables when
      approximate analytics are acceptable.
*/

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------