/**************************************************************
 * MySQL 8.0 Triggers Tutorial
 * Description: This script demonstrates row-level BEFORE and
 *              AFTER triggers in MySQL, including validation,
 *              auditing, and automatic column maintenance.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS animal_audit;
DROP TABLE IF EXISTS animal_inventory;

CREATE TABLE animal_inventory
(
    animal_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(60) NOT NULL,
    animal_type VARCHAR(60) NOT NULL,
    age INT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_animal_inventory_name (name)
) ENGINE = InnoDB;

CREATE TABLE animal_audit
(
    audit_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    action_name VARCHAR(20) NOT NULL,
    animal_id INT NULL,
    payload JSON NOT NULL,
    logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

DROP TRIGGER IF EXISTS trg_before_insert_animal_inventory;
DROP TRIGGER IF EXISTS trg_before_update_animal_inventory;
DROP TRIGGER IF EXISTS trg_after_delete_animal_inventory;

DELIMITER //

-------------------------------------------------
-- Region: 1. BEFORE INSERT Trigger
-------------------------------------------------
/*
  1.1 Reject negative ages and duplicate names.
*/
CREATE TRIGGER trg_before_insert_animal_inventory
BEFORE INSERT ON animal_inventory
FOR EACH ROW
BEGIN
    IF NEW.age < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Animal age cannot be negative.';
    END IF;

    IF EXISTS (SELECT 1 FROM animal_inventory WHERE name = NEW.name) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Animal with the same name already exists.';
    END IF;
END //

-------------------------------------------------
-- Region: 2. BEFORE UPDATE Trigger
-------------------------------------------------
/*
  2.1 Validate updates before the row is written.
*/
CREATE TRIGGER trg_before_update_animal_inventory
BEFORE UPDATE ON animal_inventory
FOR EACH ROW
BEGIN
    IF NEW.age < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Updated age cannot be negative.';
    END IF;
END //

-------------------------------------------------
-- Region: 3. AFTER DELETE Trigger
-------------------------------------------------
/*
  3.1 Write deleted row data to an audit table.
*/
CREATE TRIGGER trg_after_delete_animal_inventory
AFTER DELETE ON animal_inventory
FOR EACH ROW
BEGIN
    INSERT INTO animal_audit (action_name, animal_id, payload)
    VALUES
    (
        'DELETE',
        OLD.animal_id,
        JSON_OBJECT(
            'animal_id', OLD.animal_id,
            'name', OLD.name,
            'animal_type', OLD.animal_type,
            'age', OLD.age
        )
    );
END //

DELIMITER ;

-------------------------------------------------
-- Region: 4. Example DML
-------------------------------------------------
INSERT INTO animal_inventory (name, animal_type, age)
VALUES
    ('Atlas', 'Mammal', 6),
    ('Pico', 'Bird', 2);

UPDATE animal_inventory
SET age = 3
WHERE name = 'Pico';

DELETE FROM animal_inventory
WHERE name = 'Atlas';

-------------------------------------------------
-- Region: 5. Review Audit Data
-------------------------------------------------
SELECT *
FROM animal_audit;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------