/**************************************************************
 * MySQL 8.0 Performance Schema Tutorial
 * This script demonstrates how to use performance_schema
 * and the sys schema to monitor, diagnose, and tune
 * MySQL workloads.  It serves as the MySQL equivalent of
 * SQL Server Query Store and Extended Events.  It covers:
 * - Enabling and configuring performance_schema consumers.
 * - Statement statistics (top queries by latency / rows).
 * - Table and index I/O wait statistics.
 * - Wait event analysis (lock waits, I/O waits).
 * - sys schema views for actionable insights.
 * - Diagnosing missing indexes via performance_schema.
 * - Slow query log integration.
 * - Session and connection tracking.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Verify Performance Schema is Available
-------------------------------------------------هد
/*
  performance_schema is enabled by default in MySQL 8.0.
  Confirm it is active.
*/
SHOW VARIABLES LIKE 'performance_schema';

/*
  List available databases.
*/
SHOW DATABASES;

-------------------------------------------------
-- Region: 1. Enabling Key Consumers and Instruments
-------------------------------------------------
/*
  1.1 Check which consumers are currently active.
*/
SELECT NAME, ENABLED
FROM performance_schema.setup_consumers
ORDER BY NAME;

/*
  1.2 Enable the statement-history consumers (off by default).
*/
UPDATE performance_schema.setup_consumers
SET    ENABLED = 'YES'
WHERE  NAME IN (
    'events_statements_history',
    'events_statements_history_long',
    'events_waits_history',
    'events_waits_history_long'
);

/*
  1.3 Verify statement instrumentation is active.
*/
SELECT NAME, ENABLED, TIMED
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%'
LIMIT 10;

/*
  1.4 Enable all statement instruments and waits.
*/
UPDATE performance_schema.setup_instruments
SET    ENABLED = 'YES', TIMED = 'YES'
WHERE  NAME LIKE 'statement/%'
    OR NAME LIKE 'wait/%';

-------------------------------------------------
-- Region: 2. Statement Statistics (Top Slow Queries)
-------------------------------------------------
/*
  2.1 Top 10 queries by total combined latency (picoseconds).
*/
SELECT
    DIGEST_TEXT                                          AS query_pattern,
    COUNT_STAR                                           AS executions,
    ROUND(SUM_TIMER_WAIT / 1e12, 3)                      AS total_latency_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 6)                      AS avg_latency_sec,
    ROUND(MAX_TIMER_WAIT / 1e12, 6)                      AS max_latency_sec,
    SUM_ROWS_EXAMINED                                    AS total_rows_examined,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(COUNT_STAR, 0), 0)  AS avg_rows_examined,
    SUM_ROWS_SENT                                        AS total_rows_sent,
    SUM_NO_INDEX_USED                                    AS no_index_used
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

/*
  2.2 Queries with full-table scans (no index used).
*/
SELECT
    DIGEST_TEXT,
    COUNT_STAR        AS executions,
    SUM_NO_INDEX_USED AS full_scans
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_NO_INDEX_USED > 0
ORDER BY SUM_NO_INDEX_USED DESC
LIMIT 10;

/*
  2.3 High row-examination-to-sent ratio (index inefficiency indicator).
*/
SELECT
    DIGEST_TEXT,
    COUNT_STAR                                                       AS executions,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 1)          AS examine_to_send_ratio
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_ROWS_SENT > 0
ORDER BY examine_to_send_ratio DESC
LIMIT 10;

-------------------------------------------------
-- Region: 3. Table I/O Wait Statistics
-------------------------------------------------
/*
  3.1 Tables with the highest cumulative latency.
*/
SELECT
    OBJECT_SCHEMA                       AS db_name,
    OBJECT_NAME                         AS table_name,
    COUNT_STAR                          AS total_io_requests,
    ROUND(SUM_TIMER_WAIT / 1e12, 3)     AS total_latency_sec,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('performance_schema','information_schema',
                             'mysql','sys')
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

/*
  3.2 Index-level I/O: detect hot indexes and unused ones.
*/
SELECT
    OBJECT_NAME   AS table_name,
    INDEX_NAME,
    COUNT_READ,
    COUNT_WRITE,
    ROUND(SUM_TIMER_WAIT / 1e12, 3) AS latency_sec
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = DATABASE()
  AND INDEX_NAME   IS NOT NULL
ORDER BY SUM_TIMER_WAIT DESC;

-------------------------------------------------
-- Region: 4. Wait Event Analysis
-------------------------------------------------
/*
  4.1 Top wait events by accumulated wait time.
*/
SELECT
    EVENT_NAME,
    COUNT_STAR                      AS occurrences,
    ROUND(SUM_TIMER_WAIT / 1e12, 3) AS total_wait_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 6) AS avg_wait_sec
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE SUM_TIMER_WAIT > 0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

/*
  4.2 InnoDB lock waits (current blocking waits).
*/
SELECT *
FROM performance_schema.data_lock_waits;

/*
  4.3 Inspect detailed lock information.
*/
SELECT
    ENGINE_LOCK_ID,
    ENGINE_TRANSACTION_ID,
    THREAD_ID,
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    LOCK_TYPE,
    LOCK_MODE,
    LOCK_STATUS
FROM performance_schema.data_locks
LIMIT 20;

-------------------------------------------------
-- Region: 5. sys Schema Views (Actionable Insights)
-------------------------------------------------
/*
  5.1 Statements contributing most to server latency.
*/
SELECT query, exec_count, total_latency, avg_latency
FROM sys.statement_analysis
ORDER BY total_latency DESC
LIMIT 10;

/*
  5.2 Schemas with the most table data.
*/
SELECT * FROM sys.schema_table_statistics
ORDER BY total_latency DESC
LIMIT 10;

/*
  5.3 Unused indexes.
*/
SELECT * FROM sys.schema_unused_indexes
WHERE object_schema = DATABASE();

/*
  5.4 Redundant indexes.
*/
SELECT * FROM sys.schema_redundant_indexes
WHERE table_schema = DATABASE();

/*
  5.5 Tables without a primary key.
*/
SELECT * FROM sys.schema_tables_with_full_table_scans
LIMIT 10;

/*
  5.6 Current sessions and their resource usage.
*/
SELECT conn_id, user, db, command, time, state, current_statement
FROM sys.session
ORDER BY time DESC
LIMIT 20;

-------------------------------------------------
-- Region: 6. Slow Query Log
-------------------------------------------------
/*
  6.1 Review slow query log settings.
*/
SHOW VARIABLES LIKE 'slow_query_log%';
SHOW VARIABLES LIKE 'long_query_time';

/*
  6.2 Enable and configure the slow query log for this session.
       Set the threshold to 1 second.
*/
-- SET GLOBAL slow_query_log          = 'ON';
-- SET GLOBAL long_query_time         = 1;
-- SET GLOBAL slow_query_log_file     = '/var/log/mysql/slow.log';
-- SET GLOBAL log_queries_not_using_indexes = 'ON';

/*
  6.3 The slow log can also be routed to a table (useful for SQL analysis).
*/
-- SET GLOBAL log_output = 'TABLE';

-- After enabling, queries exceeding long_query_time appear here:
-- SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;

-------------------------------------------------
-- Region: 7. Session and Connection Tracking
-------------------------------------------------
/*
  7.1 Show active connections and their resource usage.
*/
SELECT
    ID          AS connection_id,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME        AS seconds_running,
    STATE,
    INFO        AS current_query
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE COMMAND <> 'Sleep'
ORDER BY TIME DESC;

/*
  7.2 Connection counts by user.
*/
SELECT
    USER,
    COUNT(*) AS connections
FROM INFORMATION_SCHEMA.PROCESSLIST
GROUP BY USER
ORDER BY connections DESC;

/*
  7.3 Memory usage by thread (requires memory instrumentation).
*/
SELECT
    t.PROCESSLIST_USER   AS user,
    SUM(m.CURRENT_NUMBER_OF_BYTES_USED) AS memory_bytes
FROM performance_schema.memory_summary_by_thread_by_event_name m
JOIN performance_schema.threads t ON m.THREAD_ID = t.THREAD_ID
GROUP BY t.PROCESSLIST_USER
ORDER BY memory_bytes DESC
LIMIT 10;

-------------------------------------------------
-- Region: 8. Resetting Statistics
-------------------------------------------------
/*
  8.1 Truncate all statement summary tables to start fresh after a
       workload change.
*/
-- TRUNCATE TABLE performance_schema.events_statements_summary_by_digest;
-- TRUNCATE TABLE performance_schema.events_waits_summary_global_by_event_name;

/*
  8.2 Reset all performance_schema statistics.
*/
-- CALL sys.ps_reset_statement_instrumentation();   -- requires sys schema

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
