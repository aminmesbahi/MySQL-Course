/**************************************************************
 * MySQL 8.0 Hierarchy Data Tutorial
 * Description: This script demonstrates working with hierarchical
 *              data in MySQL using the adjacency list model and
 *              recursive Common Table Expressions.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS organization;

CREATE TABLE organization
(
    employee_id INT PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    manager_id INT NULL,
    job_title VARCHAR(100) NOT NULL,
    CONSTRAINT fk_organization_manager
        FOREIGN KEY (manager_id) REFERENCES organization(employee_id)
) ENGINE = InnoDB;

INSERT INTO organization (employee_id, employee_name, manager_id, job_title)
VALUES
    (1, 'Amina', NULL, 'Chief Executive Officer'),
    (2, 'Hassan', 1, 'Engineering Director'),
    (3, 'Mona', 1, 'Sales Director'),
    (4, 'Omar', 2, 'Backend Lead'),
    (5, 'Lina', 2, 'Data Lead'),
    (6, 'Yara', 4, 'Senior Engineer'),
    (7, 'Sami', 3, 'Account Executive');

CREATE INDEX ix_organization_manager_id
ON organization (manager_id);

-------------------------------------------------
-- Region: 1. Full Hierarchy Query
-------------------------------------------------
/*
  1.1 Build a recursive hierarchy from the root node downward.
*/
WITH RECURSIVE org_chart AS
(
    SELECT
        employee_id,
        employee_name,
        manager_id,
        job_title,
        0 AS org_level,
        CAST(employee_name AS CHAR(500)) AS path_text
    FROM organization
    WHERE manager_id IS NULL

    UNION ALL

    SELECT
        child.employee_id,
        child.employee_name,
        child.manager_id,
        child.job_title,
        parent.org_level + 1 AS org_level,
        CONCAT(parent.path_text, ' > ', child.employee_name) AS path_text
    FROM organization AS child
    INNER JOIN org_chart AS parent
        ON child.manager_id = parent.employee_id
)
SELECT *
FROM org_chart
ORDER BY path_text;

-------------------------------------------------
-- Region: 2. Descendants of a Specific Manager
-------------------------------------------------
/*
  2.1 Return all descendants below employee_id = 2.
*/
WITH RECURSIVE descendants AS
(
    SELECT employee_id, employee_name, manager_id, 0 AS depth
    FROM organization
    WHERE employee_id = 2

    UNION ALL

    SELECT child.employee_id, child.employee_name, child.manager_id, parent.depth + 1
    FROM organization AS child
    INNER JOIN descendants AS parent
        ON child.manager_id = parent.employee_id
)
SELECT *
FROM descendants
ORDER BY depth, employee_id;

-------------------------------------------------
-- Region: 3. Immediate Parent Lookup
-------------------------------------------------
/*
  3.1 Find the manager of one employee.
*/
SELECT
    child.employee_name AS employee_name,
    parent.employee_name AS manager_name
FROM organization AS child
LEFT JOIN organization AS parent
    ON parent.employee_id = child.manager_id
WHERE child.employee_id = 6;

-------------------------------------------------
-- Region: 4. Updating the Hierarchy
-------------------------------------------------
/*
  4.1 Reassign one employee to a different manager.
*/
UPDATE organization
SET manager_id = 5
WHERE employee_id = 6;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------