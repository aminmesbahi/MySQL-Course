/**************************************************************
 * MySQL 8.0 Event Scheduler Tutorial
 * Description: This script demonstrates how to create and manage
 *              scheduled jobs in MySQL using the Event Scheduler,
 *              which is the closest native equivalent to SQL
 *              Server Agent jobs for recurring database tasks.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

/*
  Ensure the support table exists for event logging.
*/
CREATE TABLE IF NOT EXISTS maintenance_log
(
    log_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_name VARCHAR(100) NOT NULL,
    note VARCHAR(255) NOT NULL,
    logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 1. Event Scheduler Basics
-------------------------------------------------
/*
  1.1 Inspect the scheduler status.
*/
SHOW VARIABLES LIKE 'event_scheduler';

/*
  1.2 Enable the scheduler if you have sufficient privileges.
*/
-- SET GLOBAL event_scheduler = ON;

-------------------------------------------------
-- Region: 2. One-Time Event
-------------------------------------------------
/*
  2.1 Recreate a one-time event for demonstration purposes.
*/
DROP EVENT IF EXISTS ev_log_one_time_message;

CREATE EVENT ev_log_one_time_message
    ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 5 MINUTE
    DO
        INSERT INTO maintenance_log (event_name, note)
        VALUES ('ev_log_one_time_message', 'One-time event executed.');

-------------------------------------------------
-- Region: 3. Recurring Event
-------------------------------------------------
/*
  3.1 Create a recurring event that writes a heartbeat row.
*/
DROP EVENT IF EXISTS ev_hourly_heartbeat;

CREATE EVENT ev_hourly_heartbeat
    ON SCHEDULE EVERY 1 HOUR
    STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
    DO
        INSERT INTO maintenance_log (event_name, note)
        VALUES ('ev_hourly_heartbeat', 'Recurring heartbeat event executed.');

-------------------------------------------------
-- Region: 4. Reviewing and Altering Events
-------------------------------------------------
/*
  4.1 Review event metadata from INFORMATION_SCHEMA.
*/
SELECT
    event_schema,
    event_name,
    status,
    execute_at,
    interval_value,
    interval_field,
    starts,
    ends
FROM information_schema.events
WHERE event_schema = 'mysql_course';

/*
  4.2 Change the heartbeat interval.
*/
ALTER EVENT ev_hourly_heartbeat
    ON SCHEDULE EVERY 30 MINUTE;

-------------------------------------------------
-- Region: 5. Cleanup Example
-------------------------------------------------
/*
  5.1 Disable an event without dropping it.
*/
ALTER EVENT ev_log_one_time_message DISABLE;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------