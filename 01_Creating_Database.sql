/**************************************************************
 * MySQL 8.0 Database Tutorial
 * Description: This script demonstrates common operations for
 *              creating and managing databases in MySQL,
 *              including character sets, collations, tables,
 *              and metadata inspection.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization & Cleanup
-------------------------------------------------
/*
  Optional: Start from a clean slate.
*/
DROP DATABASE IF EXISTS mysql_course_reporting;
DROP DATABASE IF EXISTS mysql_course;

-------------------------------------------------
-- Region: 1. Creating Databases
-------------------------------------------------
/*
  1.1 Simplest way to create a database in MySQL.
*/
CREATE DATABASE mysql_course;

/*
  1.2 Creating a database with explicit character set and collation.
*/
CREATE DATABASE mysql_course_reporting
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

/*
  1.3 Change database defaults after creation.
*/
ALTER DATABASE mysql_course
    CHARACTER SET = utf8mb4
    COLLATE = utf8mb4_0900_ai_ci;

-------------------------------------------------
-- Region: 2. Working Inside the Database
-------------------------------------------------
/*
  2.1 Switch to the target database.
*/
USE mysql_course;

/*
  2.2 Create a sample table using InnoDB.
*/
CREATE TABLE departments
(
    department_id INT PRIMARY KEY AUTO_INCREMENT,
    department_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

/*
  2.3 Insert a few rows for later metadata checks.
*/
INSERT INTO departments (department_name)
VALUES
    ('Engineering'),
    ('Finance'),
    ('Sales');

-------------------------------------------------
-- Region: 3. Optional Tablespace Pattern
-------------------------------------------------
/*
  3.1 General tablespaces are the closest MySQL concept to
      manually controlled storage placement.
  Note: Keep this example commented unless your server allows
        CREATE TABLESPACE with a writable data directory path.
*/
-- CREATE TABLESPACE course_ts
--     ADD DATAFILE 'course_ts.ibd'
--     ENGINE = InnoDB;

-------------------------------------------------
-- Region: 4. Metadata Queries
-------------------------------------------------
/*
  4.1 Retrieve database defaults.
*/
SELECT
    schema_name,
    default_character_set_name,
    default_collation_name
FROM information_schema.schemata
WHERE schema_name IN ('mysql_course', 'mysql_course_reporting');

/*
  4.2 Retrieve table information for the target schema.
*/
SELECT
    table_schema,
    table_name,
    engine,
    table_rows,
    create_time
FROM information_schema.tables
WHERE table_schema = 'mysql_course';

/*
  4.3 Show server defaults that influence new schema objects.
*/
SHOW VARIABLES LIKE 'character_set_server';
SHOW VARIABLES LIKE 'collation_server';

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------