/**************************************************************
 * MySQL 8.0 Time Series Tutorial
 * Description: This script demonstrates common time-series
 *              techniques in MySQL, including:
 *              - Creating a readings table
 *              - Filtering by time window
 *              - Running totals, moving averages, and differences
 *              - Bucketing values into fixed intervals
 *              - Manual history tracking as a MySQL alternative
 *                to SQL Server temporal tables
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS time_series_history;
DROP TABLE IF EXISTS time_series_data;

CREATE TABLE time_series_data
(
    reading_id INT PRIMARY KEY AUTO_INCREMENT,
    reading_time DATETIME NOT NULL,
    sensor_id INT NOT NULL,
    reading_value DECIMAL(10, 2) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE time_series_history
(
    history_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    reading_id INT NOT NULL,
    old_value DECIMAL(10, 2) NOT NULL,
    new_value DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

DROP TRIGGER IF EXISTS trg_before_update_time_series_data;

DELIMITER //

/*
  Track value changes manually because MySQL does not provide
  system-versioned temporal tables.
*/
CREATE TRIGGER trg_before_update_time_series_data
BEFORE UPDATE ON time_series_data
FOR EACH ROW
BEGIN
    IF OLD.reading_value <> NEW.reading_value THEN
        INSERT INTO time_series_history (reading_id, old_value, new_value)
        VALUES (OLD.reading_id, OLD.reading_value, NEW.reading_value);
    END IF;
END //

DELIMITER ;

INSERT INTO time_series_data (reading_time, sensor_id, reading_value)
VALUES
    ('2023-01-01 08:00:00', 1, 10.50),
    ('2023-01-01 08:05:00', 1, 11.00),
    ('2023-01-01 08:10:00', 1, 10.75),
    ('2023-01-01 08:15:00', 1, 11.25),
    ('2023-01-01 08:20:00', 1, 10.90),
    ('2023-01-01 08:25:00', 1, 11.10),
    ('2023-01-01 08:30:00', 1, 11.00),
    ('2023-01-01 08:35:00', 1, 10.80),
    ('2023-01-01 08:40:00', 1, 11.20),
    ('2023-01-01 08:45:00', 1, 11.30);

-------------------------------------------------
-- Region: 1. Basic Time Window Queries
-------------------------------------------------
/*
  1.1 Return readings for SensorID = 1 during the morning window.
*/
SELECT *
FROM time_series_data
WHERE sensor_id = 1
  AND reading_time BETWEEN '2023-01-01 08:00:00' AND '2023-01-01 09:00:00'
ORDER BY reading_time;

-------------------------------------------------
-- Region: 2. Time Series Analysis Using Window Functions
-------------------------------------------------
/*
  2.1 Running total of readings by time.
*/
SELECT
    reading_id,
    reading_time,
    sensor_id,
    reading_value,
    SUM(reading_value) OVER (
        PARTITION BY sensor_id
        ORDER BY reading_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM time_series_data
ORDER BY reading_time;

/*
  2.2 Three-point moving average.
*/
SELECT
    reading_id,
    reading_time,
    sensor_id,
    reading_value,
    AVG(reading_value) OVER (
        PARTITION BY sensor_id
        ORDER BY reading_time
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS moving_average
FROM time_series_data
ORDER BY reading_time;

/*
  2.3 Previous, next, and difference values.
*/
SELECT
    reading_id,
    reading_time,
    sensor_id,
    reading_value,
    LAG(reading_value, 1) OVER (PARTITION BY sensor_id ORDER BY reading_time) AS previous_value,
    LEAD(reading_value, 1) OVER (PARTITION BY sensor_id ORDER BY reading_time) AS next_value,
    reading_value - LAG(reading_value, 1) OVER (PARTITION BY sensor_id ORDER BY reading_time) AS value_difference
FROM time_series_data
ORDER BY reading_time;

-------------------------------------------------
-- Region: 3. Grouping by Fixed Intervals
-------------------------------------------------
/*
  3.1 Bucket readings into 15-minute windows.
*/
SELECT
    FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(reading_time) / 900) * 900) AS time_interval,
    COUNT(*) AS reading_count,
    AVG(reading_value) AS avg_value,
    MIN(reading_value) AS min_value,
    MAX(reading_value) AS max_value
FROM time_series_data
GROUP BY FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(reading_time) / 900) * 900)
ORDER BY time_interval;

-------------------------------------------------
-- Region: 4. Manual History Tracking
-------------------------------------------------
/*
  4.1 Update one reading to generate a history row.
*/
UPDATE time_series_data
SET reading_value = 11.70
WHERE reading_id = 1;

/*
  4.2 Review the current data and the captured change history.
*/
SELECT *
FROM time_series_data
ORDER BY reading_id;

SELECT *
FROM time_series_history
ORDER BY changed_at;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------