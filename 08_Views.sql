/**************************************************************
 * MySQL 8.0 Views Tutorial
 * Description: This script demonstrates creating simple views,
 *              join views, aggregate views, and JSON-producing
 *              views in MySQL.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS animal_details;

CREATE TABLE animal_details
(
    detail_id INT PRIMARY KEY AUTO_INCREMENT,
    animal_name VARCHAR(60) NOT NULL,
    detail_text VARCHAR(255) NOT NULL
) ENGINE = InnoDB;

INSERT INTO animal_details (animal_name, detail_text)
VALUES
    ('Leo', 'Large enclosure near the east wing.'),
    ('Polly', 'Requires daily enrichment activities.'),
    ('Nemo', 'Tank temperature monitored every hour.');

DROP VIEW IF EXISTS vw_animal_names;
DROP VIEW IF EXISTS vw_animal_details;
DROP VIEW IF EXISTS vw_animal_count_by_type;
DROP VIEW IF EXISTS vw_animal_json;
DROP VIEW IF EXISTS vw_animal_age_category;

-------------------------------------------------
-- Region: 1. Simple View
-------------------------------------------------
/*
  1.1 View of animal names.
*/
CREATE VIEW vw_animal_names AS
SELECT name
FROM animals;

-------------------------------------------------
-- Region: 2. Join View
-------------------------------------------------
/*
  2.1 Join animals with supporting detail rows.
*/
CREATE VIEW vw_animal_details AS
SELECT
    a.animal_id,
    a.name,
    a.animal_type,
    a.age,
    d.detail_text
FROM animals AS a
LEFT JOIN animal_details AS d
    ON d.animal_name = a.name;

-------------------------------------------------
-- Region: 3. Aggregate View
-------------------------------------------------
/*
  3.1 Count animals by type.
*/
CREATE VIEW vw_animal_count_by_type AS
SELECT
    animal_type,
    COUNT(*) AS animal_count,
    AVG(age) AS average_age
FROM animals
GROUP BY animal_type;

-------------------------------------------------
-- Region: 4. JSON View
-------------------------------------------------
/*
  4.1 Create a JSON representation per animal row.
*/
CREATE VIEW vw_animal_json AS
SELECT
    animal_id,
    name,
    JSON_OBJECT(
        'animal_id', animal_id,
        'name', name,
        'animal_type', animal_type,
        'age', age
    ) AS animal_json
FROM animals;

-------------------------------------------------
-- Region: 5. Computed View
-------------------------------------------------
/*
  5.1 Categorize animals by age.
*/
CREATE VIEW vw_animal_age_category AS
SELECT
    name,
    age,
    CASE
        WHEN age < 1 THEN 'Infant'
        WHEN age BETWEEN 1 AND 3 THEN 'Young'
        WHEN age BETWEEN 4 AND 7 THEN 'Adult'
        ELSE 'Senior'
    END AS age_category
FROM animals;

-------------------------------------------------
-- Region: 6. Example Queries
-------------------------------------------------
SELECT * FROM vw_animal_names;
SELECT * FROM vw_animal_details;
SELECT * FROM vw_animal_count_by_type;
SELECT * FROM vw_animal_json;
SELECT * FROM vw_animal_age_category;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------