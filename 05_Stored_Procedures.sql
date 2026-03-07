/**************************************************************
 * MySQL 8.0 Stored Procedures Tutorial
 * Description: This script demonstrates creating stored
 *              procedures in MySQL for basic lookups, output
 *              parameters, JSON input, error handling, and
 *              transactional updates.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS animals;

CREATE TABLE animals
(
    animal_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(60) NOT NULL,
    animal_type VARCHAR(60) NOT NULL,
    age INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_animals_name (name)
) ENGINE = InnoDB;

INSERT INTO animals (name, animal_type, age)
VALUES
    ('Leo', 'Mammal', 5),
    ('Polly', 'Bird', 2),
    ('Nemo', 'Fish', 1);

DROP PROCEDURE IF EXISTS GetAnimalByName;
DROP PROCEDURE IF EXISTS AddAnimal;
DROP PROCEDURE IF EXISTS GetAnimalCountByType;
DROP PROCEDURE IF EXISTS AddAnimalFromJSON;
DROP PROCEDURE IF EXISTS TransferAnimal;

DELIMITER //

-------------------------------------------------
-- Region: 1. Simple Stored Procedure
-------------------------------------------------
/*
  1.1 GetAnimalByName: Returns animal information for one name.
*/
CREATE PROCEDURE GetAnimalByName(IN p_name VARCHAR(60))
BEGIN
    SELECT animal_id, name, animal_type, age
    FROM animals
    WHERE name = p_name;
END //

-------------------------------------------------
-- Region: 2. Procedure with Error Handling
-------------------------------------------------
/*
  2.1 AddAnimal: Inserts a row and returns diagnostics on failure.
*/
CREATE PROCEDURE AddAnimal(
    IN p_name VARCHAR(60),
    IN p_type VARCHAR(60),
    IN p_age INT
)
BEGIN
    DECLARE v_sqlstate CHAR(5) DEFAULT '00000';
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_message TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno = MYSQL_ERRNO,
            v_message = MESSAGE_TEXT;

        ROLLBACK;

        SELECT
            v_sqlstate AS sqlstate_value,
            v_errno AS mysql_errno,
            v_message AS error_message;
    END;

    START TRANSACTION;

    INSERT INTO animals (name, animal_type, age)
    VALUES (p_name, p_type, p_age);

    COMMIT;
END //

-------------------------------------------------
-- Region: 3. Procedure with Output Parameter
-------------------------------------------------
/*
  3.1 GetAnimalCountByType: Returns a count using an OUT parameter.
*/
CREATE PROCEDURE GetAnimalCountByType(
    IN p_type VARCHAR(60),
    OUT p_count INT
)
BEGIN
    SELECT COUNT(*)
    INTO p_count
    FROM animals
    WHERE animal_type = p_type;
END //

-------------------------------------------------
-- Region: 4. Procedure with JSON Input
-------------------------------------------------
/*
  4.1 AddAnimalFromJSON: Parses a JSON document and inserts one row.
  Expected JSON format:
  {"Name": "Kiki", "Type": "Bird", "Age": 3}
*/
CREATE PROCEDURE AddAnimalFromJSON(IN p_animal JSON)
BEGIN
    INSERT INTO animals (name, animal_type, age)
    VALUES
    (
        JSON_UNQUOTE(JSON_EXTRACT(p_animal, '$.Name')),
        JSON_UNQUOTE(JSON_EXTRACT(p_animal, '$.Type')),
        JSON_EXTRACT(p_animal, '$.Age')
    );
END //

-------------------------------------------------
-- Region: 5. Transactional Update Procedure
-------------------------------------------------
/*
  5.1 TransferAnimal: Changes an animal type with validation.
*/
CREATE PROCEDURE TransferAnimal(
    IN p_animal_id INT,
    IN p_new_type VARCHAR(60)
)
BEGIN
    START TRANSACTION;

    UPDATE animals
    SET animal_type = p_new_type
    WHERE animal_id = p_animal_id;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No animal found with the provided animal_id.';
    END IF;

    COMMIT;
END //

DELIMITER ;

-------------------------------------------------
-- Region: 6. Example Calls
-------------------------------------------------
CALL GetAnimalByName('Leo');

CALL AddAnimal('Daisy', 'Mammal', 4);

SET @animal_count = 0;
CALL GetAnimalCountByType('Mammal', @animal_count);
SELECT @animal_count AS mammal_count;

CALL AddAnimalFromJSON('{"Name": "Kiki", "Type": "Bird", "Age": 3}');

CALL TransferAnimal(1, 'Big Cat');

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------