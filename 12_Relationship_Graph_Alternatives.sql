/**************************************************************
 * MySQL 8.0 Relationship Modeling Tutorial
 * Description: This script demonstrates how to model graph-like
 *              data in MySQL using ordinary relational tables,
 *              foreign keys, and joins instead of SQL Server
 *              node and edge tables.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS friendship;
DROP TABLE IF EXISTS lives_in;
DROP TABLE IF EXISTS city;
DROP TABLE IF EXISTS person;

CREATE TABLE person
(
    person_id INT PRIMARY KEY,
    person_name VARCHAR(100) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE city
(
    city_id INT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE lives_in
(
    person_id INT NOT NULL,
    city_id INT NOT NULL,
    PRIMARY KEY (person_id, city_id),
    CONSTRAINT fk_lives_in_person FOREIGN KEY (person_id) REFERENCES person(person_id),
    CONSTRAINT fk_lives_in_city FOREIGN KEY (city_id) REFERENCES city(city_id)
) ENGINE = InnoDB;

CREATE TABLE friendship
(
    person_id INT NOT NULL,
    friend_id INT NOT NULL,
    since_date DATE NOT NULL,
    PRIMARY KEY (person_id, friend_id),
    CONSTRAINT fk_friendship_person FOREIGN KEY (person_id) REFERENCES person(person_id),
    CONSTRAINT fk_friendship_friend FOREIGN KEY (friend_id) REFERENCES person(person_id)
) ENGINE = InnoDB;

INSERT INTO person (person_id, person_name)
VALUES
    (1, 'Alice'),
    (2, 'Bob'),
    (3, 'Charlie');

INSERT INTO city (city_id, city_name)
VALUES
    (1, 'New York'),
    (2, 'Los Angeles'),
    (3, 'Chicago');

INSERT INTO lives_in (person_id, city_id)
VALUES
    (1, 1),
    (2, 2),
    (3, 3);

INSERT INTO friendship (person_id, friend_id, since_date)
VALUES
    (1, 2, '2023-01-01'),
    (2, 3, '2023-02-01'),
    (1, 3, '2023-03-01');

-------------------------------------------------
-- Region: 1. Basic Relationship Query
-------------------------------------------------
/*
  1.1 Retrieve all people and their cities.
*/
SELECT
    p.person_name,
    c.city_name
FROM person AS p
INNER JOIN lives_in AS li
    ON li.person_id = p.person_id
INNER JOIN city AS c
    ON c.city_id = li.city_id;

-------------------------------------------------
-- Region: 2. Traversing Person-to-Person Relationships
-------------------------------------------------
/*
  2.1 Retrieve each friendship edge with names.
*/
SELECT
    p.person_name AS person_name,
    f.person_name AS friend_name,
    fs.since_date
FROM friendship AS fs
INNER JOIN person AS p
    ON p.person_id = fs.person_id
INNER JOIN person AS f
    ON f.person_id = fs.friend_id;

-------------------------------------------------
-- Region: 3. JSON Representation
-------------------------------------------------
/*
  3.1 Construct a JSON document from relational graph-like data.
*/
SELECT
    p.person_name,
    JSON_OBJECT(
        'person', p.person_name,
        'city', c.city_name
    ) AS person_city_json
FROM person AS p
INNER JOIN lives_in AS li
    ON li.person_id = p.person_id
INNER JOIN city AS c
    ON c.city_id = li.city_id;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------