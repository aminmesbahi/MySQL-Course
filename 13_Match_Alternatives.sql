/**************************************************************
 * MySQL 8.0 Relationship Pattern Tutorial
 * Description: This script replaces SQL Server graph MATCH
 *              examples with join-based and recursive queries in
 *              MySQL. The goal is the same: express relationship
 *              patterns, just without graph-specific syntax.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

-------------------------------------------------
-- Region: 1. Basic Pattern Query
-------------------------------------------------
/*
  1.1 Person -> City pattern using standard joins.
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
-- Region: 2. Pattern Query with Filtering
-------------------------------------------------
/*
  2.1 Filter the pattern by city name.
*/
SELECT
    p.person_name,
    c.city_name
FROM person AS p
INNER JOIN lives_in AS li
    ON li.person_id = p.person_id
INNER JOIN city AS c
    ON c.city_id = li.city_id
WHERE c.city_name = 'New York';

-------------------------------------------------
-- Region: 3. Multi-Hop Relationship Pattern
-------------------------------------------------
/*
  3.1 Find friend-of-a-friend relationships.
*/
SELECT
    start_person.person_name AS start_person,
    middle_person.person_name AS direct_friend,
    end_person.person_name AS friend_of_friend
FROM friendship AS first_hop
INNER JOIN friendship AS second_hop
    ON second_hop.person_id = first_hop.friend_id
INNER JOIN person AS start_person
    ON start_person.person_id = first_hop.person_id
INNER JOIN person AS middle_person
    ON middle_person.person_id = first_hop.friend_id
INNER JOIN person AS end_person
    ON end_person.person_id = second_hop.friend_id;

-------------------------------------------------
-- Region: 4. Recursive Traversal
-------------------------------------------------
/*
  4.1 Recursively walk outward from Alice.
*/
WITH RECURSIVE friendship_path AS
(
    SELECT
        p.person_id,
        p.person_name,
        p.person_id AS root_person_id,
        CAST(p.person_name AS CHAR(500)) AS path_text,
        0 AS depth
    FROM person AS p
    WHERE p.person_name = 'Alice'

    UNION ALL

    SELECT
        next_person.person_id,
        next_person.person_name,
        fp.root_person_id,
        CONCAT(fp.path_text, ' -> ', next_person.person_name) AS path_text,
        fp.depth + 1
    FROM friendship_path AS fp
    INNER JOIN friendship AS fs
        ON fs.person_id = fp.person_id
    INNER JOIN person AS next_person
        ON next_person.person_id = fs.friend_id
    WHERE fp.depth < 2
)
SELECT *
FROM friendship_path
ORDER BY depth, person_name;

-------------------------------------------------
-- Region: 5. JSON Output
-------------------------------------------------
/*
  5.1 Return the pattern result as JSON text.
*/
SELECT
    p.person_name,
    c.city_name,
    JSON_OBJECT('person_name', p.person_name, 'city_name', c.city_name) AS person_city_json
FROM person AS p
INNER JOIN lives_in AS li
    ON li.person_id = p.person_id
INNER JOIN city AS c
    ON c.city_id = li.city_id;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------