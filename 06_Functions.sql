/**************************************************************
 * MySQL 8.0 Functions Tutorial
 * Description: This script demonstrates scalar stored functions
 *              in MySQL. Because MySQL does not support table-
 *              valued functions, set-returning logic is modeled
 *              with views, CTEs, or ordinary SELECT statements.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP FUNCTION IF EXISTS GetAnimalType;
DROP FUNCTION IF EXISTS SafeDivide;
DROP FUNCTION IF EXISTS GetAnimalAgeCategory;
DROP FUNCTION IF EXISTS GetAnimalNamesByType;

DELIMITER //

-------------------------------------------------
-- Region: 1. Simple Scalar Function
-------------------------------------------------
/*
  1.1 GetAnimalType: Returns the type of an animal by name.
*/
CREATE FUNCTION GetAnimalType(p_name VARCHAR(60))
RETURNS VARCHAR(60)
READS SQL DATA
BEGIN
    DECLARE v_type VARCHAR(60);

    SELECT animal_type
    INTO v_type
    FROM animals
    WHERE name = p_name
    LIMIT 1;

    RETURN v_type;
END //

-------------------------------------------------
-- Region: 2. Safe Arithmetic Function
-------------------------------------------------
/*
  2.1 SafeDivide: Returns NULL when the denominator is zero.
*/
CREATE FUNCTION SafeDivide(p_numerator DECIMAL(18, 4), p_denominator DECIMAL(18, 4))
RETURNS DECIMAL(18, 4)
DETERMINISTIC
BEGIN
    IF p_denominator = 0 THEN
        RETURN NULL;
    END IF;

    RETURN p_numerator / p_denominator;
END //

-------------------------------------------------
-- Region: 3. CASE-Based Function
-------------------------------------------------
/*
  3.1 GetAnimalAgeCategory: Categorizes an age value.
*/
CREATE FUNCTION GetAnimalAgeCategory(p_age INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN p_age < 1 THEN 'Infant'
        WHEN p_age BETWEEN 1 AND 3 THEN 'Young'
        WHEN p_age BETWEEN 4 AND 7 THEN 'Adult'
        ELSE 'Senior'
    END;
END //

-------------------------------------------------
-- Region: 4. Aggregation Function
-------------------------------------------------
/*
  4.1 GetAnimalNamesByType: Aggregates names into one string.
*/
CREATE FUNCTION GetAnimalNamesByType(p_type VARCHAR(60))
RETURNS TEXT
READS SQL DATA
BEGIN
    DECLARE v_names TEXT;

    SELECT GROUP_CONCAT(name ORDER BY name SEPARATOR ', ')
    INTO v_names
    FROM animals
    WHERE animal_type = p_type;

    RETURN v_names;
END //

DELIMITER ;

-------------------------------------------------
-- Region: 5. MySQL Alternative to Table-Valued Functions
-------------------------------------------------
/*
  5.1 MySQL functions return scalar values only.
      For set-returning logic, use a CTE or a view instead.
*/
WITH animals_older_than_three AS
(
    SELECT name, animal_type, age
    FROM animals
    WHERE age > 3
)
SELECT *
FROM animals_older_than_three;

-------------------------------------------------
-- Region: 6. Example Queries
-------------------------------------------------
SELECT GetAnimalType('Leo') AS animal_type_for_leo;

SELECT SafeDivide(10, 2) AS normal_division,
       SafeDivide(10, 0) AS safe_division;

SELECT
    name,
    age,
    GetAnimalAgeCategory(age) AS age_category
FROM animals;

SELECT GetAnimalNamesByType('Bird') AS bird_names;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------