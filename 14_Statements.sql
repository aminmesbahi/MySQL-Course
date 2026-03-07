/**************************************************************
 * MySQL 8.0 Statements Tutorial
 * Description: This script demonstrates how indexes support
 *              common query predicates in MySQL and reviews the
 *              practical effect of filtering, grouping, joining,
 *              and sorting.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS other_data;
DROP TABLE IF EXISTS sample_data;

CREATE TABLE sample_data
(
    id INT PRIMARY KEY,
    person_name VARCHAR(100) NOT NULL,
    age INT NOT NULL,
    created_date DATETIME NOT NULL
) ENGINE = InnoDB;

CREATE TABLE other_data
(
    id INT PRIMARY KEY,
    description_text VARCHAR(100) NOT NULL
) ENGINE = InnoDB;

CREATE INDEX ix_sample_data_person_name ON sample_data (person_name);
CREATE INDEX ix_sample_data_age ON sample_data (age);
CREATE INDEX ix_sample_data_created_date ON sample_data (created_date);

INSERT INTO sample_data (id, person_name, age, created_date)
VALUES
    (1, 'Alice', 30, '2023-01-01 09:00:00'),
    (2, 'Bob', 25, '2023-02-01 09:00:00'),
    (3, 'Charlie', 35, '2023-03-01 09:00:00'),
    (4, 'David', 40, '2023-04-01 09:00:00'),
    (5, 'Eve', 28, '2023-05-01 09:00:00');

INSERT INTO other_data (id, description_text)
VALUES
    (1, 'Description 1'),
    (2, 'Description 2'),
    (3, 'Description 3'),
    (4, 'Description 4'),
    (5, 'Description 5');

-------------------------------------------------
-- Region: 1. Equality, Range, and Set Predicates
-------------------------------------------------
EXPLAIN
SELECT *
FROM sample_data
WHERE person_name = 'Alice';

EXPLAIN
SELECT *
FROM sample_data
WHERE age >= 30;

EXPLAIN
SELECT *
FROM sample_data
WHERE created_date BETWEEN '2023-01-01' AND '2023-03-31';

EXPLAIN
SELECT *
FROM sample_data
WHERE person_name IN ('Alice', 'Bob');

-------------------------------------------------
-- Region: 2. Function-Based Predicates
-------------------------------------------------
/*
  These patterns are often less index-friendly because the column
  value is wrapped inside another expression.
*/
EXPLAIN
SELECT *
FROM sample_data
WHERE LEFT(person_name, 1) = 'A';

EXPLAIN
SELECT *
FROM sample_data
WHERE YEAR(created_date) = 2023;

-------------------------------------------------
-- Region: 3. LIKE Patterns
-------------------------------------------------
EXPLAIN
SELECT *
FROM sample_data
WHERE person_name LIKE 'A%';

EXPLAIN
SELECT *
FROM sample_data
WHERE person_name LIKE '%e';

-------------------------------------------------
-- Region: 4. Sorting and Joining
-------------------------------------------------
SELECT *
FROM sample_data
ORDER BY age;

SELECT
    sd.person_name,
    od.description_text
FROM sample_data AS sd
INNER JOIN other_data AS od
    ON od.id = sd.id;

-------------------------------------------------
-- Region: 5. Statement Processing Example
-------------------------------------------------
/*
  The logical order remains FROM, WHERE, GROUP BY, HAVING,
  SELECT, and ORDER BY.
*/
SELECT
    person_name,
    COUNT(*) AS row_count
FROM sample_data
WHERE age >= 30
GROUP BY person_name
HAVING COUNT(*) > 0
ORDER BY person_name;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------