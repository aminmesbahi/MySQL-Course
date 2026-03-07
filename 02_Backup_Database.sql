/**************************************************************
 * MySQL 8.0 Backup Tutorial
 * Description: This script outlines common MySQL backup and
 *              restore patterns using native SQL commands for
 *              consistency checks and command-line tools such as
 *              mysqldump and mysql for the actual backup work.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Environment Inspection
-------------------------------------------------
/*
  0.1 Review important backup-related server settings.
*/
SHOW VARIABLES LIKE 'datadir';
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';

/*
  0.2 Confirm the target database exists before backing it up.
*/
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'mysql_course';

-------------------------------------------------
-- Region: 1. Logical Backup Workflow
-------------------------------------------------
/*
  1.1 Example full logical backup command.
  Run this from the operating system shell, not inside MySQL.

  mysqldump --routines --triggers --events --single-transaction \
      mysql_course > mysql_course_full.sql
*/

/*
  1.2 Capture binary log coordinates for point-in-time recovery.
  Acquire the read lock only for the duration required to inspect
  the log position.
*/
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
UNLOCK TABLES;

-------------------------------------------------
-- Region: 2. Backup Variations
-------------------------------------------------
/*
  2.1 Schema-only backup.

  mysqldump --no-data mysql_course > mysql_course_schema.sql
*/

/*
  2.2 Data-only backup.

  mysqldump --no-create-info mysql_course > mysql_course_data.sql
*/

/*
  2.3 Single-table backup.

  mysqldump mysql_course departments > departments.sql
*/

-------------------------------------------------
-- Region: 3. Restore Workflow
-------------------------------------------------
/*
  3.1 Example restore commands.

  mysql mysql_course < mysql_course_full.sql
  mysql mysql_course < mysql_course_schema.sql
  mysql mysql_course < mysql_course_data.sql
*/

/*
  3.2 Review available binary logs when planning recovery.
*/
SHOW BINARY LOGS;

-------------------------------------------------
-- Region: 4. Validation Queries
-------------------------------------------------
/*
  4.1 Verify object counts after a restore.
*/
SELECT
    table_schema,
    COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'mysql_course'
GROUP BY table_schema;

/*
  4.2 Optional checksum validation for restored tables.
*/
CHECKSUM TABLE mysql_course.departments;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------