/**************************************************************
 * MySQL 8.0: Localization – Character Sets, Collations & Date/Time
 * This script demonstrates how MySQL handles
 * internationalisation:
 *  1. Character sets and collations – server / database /
 *     table / column level.
 *  2. utf8mb4 – the correct 4-byte Unicode encoding.
 *  3. Collation comparison rules and case sensitivity.
 *  4. CONVERT() to switch a string between encodings.
 *  5. DATE_FORMAT() and locale-style date patterns.
 *  6. CONVERT_TZ() for time-zone-aware storage.
 *  7. Collation-sensitive sorting and searching.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS multilingual_products;
DROP TABLE IF EXISTS events_tz;

CREATE TABLE multilingual_products
(
    product_id   INT          PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(200) NOT NULL
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    description  TEXT
        CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,    -- case/accent sensitive
    price        DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE events_tz
(
    event_id   INT          PRIMARY KEY AUTO_INCREMENT,
    event_name VARCHAR(100) NOT NULL,
    event_ts   DATETIME     NOT NULL,    -- stored in UTC
    timezone   VARCHAR(64)  NOT NULL DEFAULT 'UTC'
) ENGINE = InnoDB;

INSERT INTO multilingual_products (product_name, description, price) VALUES
    ('Café Latte',         'Rich espresso with steamed milk',  4.50),
    ('Naïve Résumé',       'Accent test row',                   0.00),
    ('日本語テスト',        'Japanese character test',            0.00),
    ('Привет мир',         'Russian Cyrillic test',              0.00),
    ('Emoji Test 😃🚀',    'Four-byte emoji test',              0.00);

INSERT INTO events_tz (event_name, event_ts, timezone) VALUES
    ('Product Launch',  '2024-06-15 14:00:00', 'America/New_York'),
    ('Webinar',         '2024-09-01 09:00:00', 'Europe/London'),
    ('Maintenance',     '2024-12-31 23:00:00', 'Asia/Tokyo');

-------------------------------------------------
-- Region: 1. Character Sets – Server, Database, Table, Column
-------------------------------------------------
/*
  1.1  MySQL supports hundreds of character sets.  The recommended
       default for new databases is utf8mb4 (true 4-byte UTF-8).
       The older 'utf8' alias is 3-byte only and cannot store emoji
       or supplementary Unicode characters (code points > U+FFFF).
*/

-- View server default (my.cnf: character_set_server = utf8mb4)
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';

-- List available character sets
SHOW CHARACTER SET LIKE 'utf8%';

-- Check what a specific database uses
SELECT DEFAULT_CHARACTER_SET_NAME,
       DEFAULT_COLLATION_NAME
FROM   INFORMATION_SCHEMA.SCHEMATA
WHERE  SCHEMA_NAME = 'mysql_course';

-- Check column-level encoding
SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_SCHEMA = 'mysql_course'
  AND  TABLE_NAME   = 'multilingual_products';

-------------------------------------------------
-- Region: 2. Collations – Case and Accent Sensitivity
-------------------------------------------------
/*
  2.1  A collation defines how strings are compared and sorted.
       Common utf8mb4 collations:
         utf8mb4_general_ci  – case-insensitive, accent-insensitive (fast)
         utf8mb4_unicode_ci  – case-insensitive, accent-insensitive (Unicode-correct)
         utf8mb4_unicode_520_ci – improved Unicode 5.2 rules
         utf8mb4_0900_ai_ci  – MySQL 8.0 default; Unicode 9 accent-insensitive CI
         utf8mb4_0900_as_cs  – accent-sensitive, case-sensitive
         utf8mb4_bin         – binary (exact byte comparison; case/accent sensitive)
*/
SHOW COLLATION WHERE Charset = 'utf8mb4' AND Collation LIKE '%0900%';

-- Case-insensitive search (default utf8mb4_unicode_ci)
SELECT product_name
FROM   multilingual_products
WHERE  product_name = 'café latte';          -- matches 'Café Latte' due to ci collation

-- Force a case-sensitive comparison with COLLATE
SELECT product_name
FROM   multilingual_products
WHERE  product_name COLLATE utf8mb4_bin = 'Café Latte';

-- Sort order varies by collation
SELECT product_name
FROM   multilingual_products
ORDER  BY product_name COLLATE utf8mb4_unicode_ci;

SELECT product_name
FROM   multilingual_products
ORDER  BY product_name COLLATE utf8mb4_bin;  -- binary order

-------------------------------------------------
-- Region: 3. CONVERT() – Switch Between Character Sets
-------------------------------------------------
/*
  3.1  CONVERT(str USING charset) converts a string into a different
       character set.  This is useful when receiving data in latin1 that
       needs to be stored as utf8mb4.
*/

-- Convert a string from latin1 to utf8mb4
SELECT CONVERT('Crème brûlée' USING utf8mb4) AS converted;

-- CAST ... CHARACTER SET syntax (alternative)
SELECT CAST('résumé' AS CHAR CHARACTER SET utf8mb4) AS casted;

-- Check string byte length vs character length
SELECT product_name,
       CHAR_LENGTH(product_name)  AS char_len,
       LENGTH(product_name)       AS byte_len        -- emoji is 4 bytes
FROM   multilingual_products;

-------------------------------------------------
-- Region: 4. Altering Character Set / Collation
-------------------------------------------------
/*
  4.1  You can change the character set and collation of an existing
       column without recreating the table.  CONVERT TO rewrites all
       row data in the new encoding.
*/

-- Change entire table encoding (rewrites all character data)
-- ALTER TABLE multilingual_products CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Change a single column collation
ALTER TABLE multilingual_products
    MODIFY COLUMN product_name VARCHAR(200)
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

-- Verify
SELECT COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_SCHEMA = 'mysql_course'
  AND  TABLE_NAME   = 'multilingual_products'
  AND  COLUMN_NAME  = 'product_name';

-------------------------------------------------
-- Region: 5. DATE_FORMAT() – Locale-Style Date Patterns
-------------------------------------------------
/*
  5.1  DATE_FORMAT() formats a DATE or DATETIME using strftime-style
       specifiers.  MySQL does not have built-in locale objects, so
       format strings must be written explicitly.

  Common specifiers:
      %Y  – 4-digit year       %y – 2-digit year
      %m  – 2-digit month      %M – month name (January ..)
      %d  – 2-digit day        %D – day with suffix (1st, 2nd ..)
      %H  – 24-h hour          %h – 12-h hour
      %i  – minutes            %s – seconds
      %p  – AM/PM
      %W  – weekday name       %a – abbreviated weekday
*/
SELECT event_name,
       DATE_FORMAT(event_ts, '%W, %M %D %Y at %h:%i %p')  AS us_long,
       DATE_FORMAT(event_ts, '%d/%m/%Y %H:%i')             AS uk_short,
       DATE_FORMAT(event_ts, '%Y-%m-%dT%H:%i:%s')          AS iso8601
FROM   events_tz;

-- Extract parts
SELECT DATE_FORMAT(NOW(), '%Y')  AS current_year,
       DATE_FORMAT(NOW(), '%M')  AS current_month,
       DAYNAME(NOW())            AS weekday_name,
       WEEK(NOW(), 3)            AS iso_week_number;

-------------------------------------------------
-- Region: 6. CONVERT_TZ() – Time Zone Handling
-------------------------------------------------
/*
  6.1  Store all timestamps in UTC inside the database; convert to the
       user's local time zone at query time.  The MySQL time zone tables
       must be populated (mysql_tzinfo_to_sql on Unix; or download on Windows).
*/

-- Check available named time zones
-- SELECT * FROM mysql.time_zone_name LIMIT 10;

-- Convert UTC → user local time
SELECT event_name,
       event_ts                                       AS stored_utc,
       CONVERT_TZ(event_ts, 'UTC', timezone)         AS local_time,
       CONVERT_TZ(event_ts, 'UTC', 'America/Chicago') AS chicago_time
FROM   events_tz;

-- Store a local time as UTC
INSERT INTO events_tz (event_name, event_ts, timezone)
VALUES (
    'Conference',
    CONVERT_TZ('2024-11-05 09:00:00', 'Europe/Berlin', 'UTC'),
    'Europe/Berlin'
);

SELECT event_name, event_ts AS utc_stored, timezone
FROM   events_tz
WHERE  event_name = 'Conference';

-------------------------------------------------
-- Region: 7. Collation-Sensitive Search with LIKE
-------------------------------------------------
/*
  7.1  LIKE inherits the column collation.  With a case-insensitive
       collation, 'café%' matches 'Café Latte'.

  7.2  To force a case-sensitive LIKE, override with COLLATE.
*/
-- Case-insensitive LIKE (ci collation inherited)
SELECT product_name FROM multilingual_products
WHERE  product_name LIKE 'café%';

-- Case-sensitive LIKE
SELECT product_name FROM multilingual_products
WHERE  product_name LIKE 'Café%' COLLATE utf8mb4_bin;

-- Accent-insensitive search (0900_ai_ci)
SELECT product_name FROM multilingual_products
WHERE  product_name LIKE 'naive%' COLLATE utf8mb4_0900_ai_ci;

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS events_tz;
DROP TABLE IF EXISTS multilingual_products;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
