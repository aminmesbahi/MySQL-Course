/**************************************************************
 * MySQL 8.0 Prediction Alternatives Tutorial
 * Description: This script demonstrates practical SQL-based
 *              forecasting and scoring patterns in MySQL as an
 *              alternative to the SQL Server PREDICT clause.
 *              It covers:
 *              - Moving-average forecasts
 *              - Linear trend estimation using least squares
 *              - Rule-based scoring for simple classification
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS demand_history;

CREATE TABLE demand_history
(
    period_id INT PRIMARY KEY,
    period_start DATE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    units_sold INT NOT NULL,
    marketing_spend DECIMAL(10, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO demand_history (period_id, period_start, product_name, units_sold, marketing_spend)
VALUES
    (1, '2023-01-01', 'Product A', 120, 1000.00),
    (2, '2023-02-01', 'Product A', 128, 1100.00),
    (3, '2023-03-01', 'Product A', 131, 1050.00),
    (4, '2023-04-01', 'Product A', 142, 1150.00),
    (5, '2023-05-01', 'Product A', 150, 1200.00),
    (6, '2023-06-01', 'Product A', 158, 1225.00),
    (7, '2023-01-01', 'Product B', 85, 700.00),
    (8, '2023-02-01', 'Product B', 88, 720.00),
    (9, '2023-03-01', 'Product B', 91, 740.00),
    (10, '2023-04-01', 'Product B', 95, 760.00),
    (11, '2023-05-01', 'Product B', 97, 780.00),
    (12, '2023-06-01', 'Product B', 101, 790.00);

-------------------------------------------------
-- Region: 1. Moving Average Forecast
-------------------------------------------------
/*
  1.1 Use the last 3 periods to build a simple forecast baseline.
*/
WITH product_series AS
(
    SELECT
        product_name,
        period_id,
        period_start,
        units_sold,
        AVG(units_sold) OVER (
            PARTITION BY product_name
            ORDER BY period_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3
    FROM demand_history
)
SELECT *
FROM product_series
ORDER BY product_name, period_start;

-------------------------------------------------
-- Region: 2. Linear Trend Estimation
-------------------------------------------------
/*
  2.1 Estimate a simple linear trend y = a + bx per product.
      Here x is the sequence number within each product.
*/
WITH numbered_history AS
(
    SELECT
        product_name,
        period_start,
        units_sold,
        ROW_NUMBER() OVER (PARTITION BY product_name ORDER BY period_start) AS x_value
    FROM demand_history
),
trend_components AS
(
    SELECT
        product_name,
        COUNT(*) AS n_value,
        SUM(x_value) AS sum_x,
        SUM(units_sold) AS sum_y,
        SUM(x_value * units_sold) AS sum_xy,
        SUM(x_value * x_value) AS sum_x2
    FROM numbered_history
    GROUP BY product_name
),
trend_model AS
(
    SELECT
        product_name,
        (n_value * sum_xy - sum_x * sum_y) / NULLIF(n_value * sum_x2 - sum_x * sum_x, 0) AS slope,
        (sum_y - ((n_value * sum_xy - sum_x * sum_y) / NULLIF(n_value * sum_x2 - sum_x * sum_x, 0)) * sum_x) / n_value AS intercept,
        n_value
    FROM trend_components
)
SELECT
    product_name,
    ROUND(slope, 4) AS slope,
    ROUND(intercept, 4) AS intercept,
    ROUND(intercept + slope * (n_value + 1), 2) AS next_period_prediction
FROM trend_model;

-------------------------------------------------
-- Region: 3. Rule-Based Scoring
-------------------------------------------------
/*
  3.1 Use CASE expressions for a simple demand score.
*/
SELECT
    product_name,
    period_start,
    units_sold,
    marketing_spend,
    CASE
        WHEN units_sold >= 150 AND marketing_spend >= 1200 THEN 'High Demand'
        WHEN units_sold >= 100 THEN 'Stable Demand'
        ELSE 'Watch List'
    END AS demand_score
FROM demand_history
ORDER BY product_name, period_start;

-------------------------------------------------
-- Region: 4. Notes
-------------------------------------------------
/*
  4.1 MySQL does not include a native PREDICT clause. In practice,
      prediction workloads are usually handled by:
      - SQL-based heuristics such as moving averages and trends
      - Pre-scored results loaded from Python or another ML tool
      - Application-side inference with stored predictions written
        back to MySQL tables
*/

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------