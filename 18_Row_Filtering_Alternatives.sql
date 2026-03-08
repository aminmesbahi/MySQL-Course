/**************************************************************
 * MySQL 8.0 Row Filtering Tutorial
 * Description: This script demonstrates practical row-filtering
 *              patterns in MySQL as an alternative to SQL Server
 *              Row-Level Security (RLS). It uses:
 *              - A base orders table
 *              - A user-to-customer access map
 *              - A filtered view based on the current MySQL user
 *              - Guidance on restricting direct table access
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP VIEW IF EXISTS vw_orders_for_current_user;
DROP TABLE IF EXISTS user_customer_access;
DROP TABLE IF EXISTS secured_orders;

CREATE TABLE secured_orders
(
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE user_customer_access
(
    mysql_user_name VARCHAR(100) NOT NULL,
    customer_id INT NOT NULL,
    PRIMARY KEY (mysql_user_name, customer_id)
) ENGINE = InnoDB;

INSERT INTO secured_orders (order_id, customer_id, order_date, amount)
VALUES
    (1, 1, '2023-01-01', 100.00),
    (2, 2, '2023-01-02', 150.00),
    (3, 1, '2023-01-03', 200.00),
    (4, 3, '2023-01-04', 250.00),
    (5, 2, '2023-01-05', 300.00);

/*
  Sample mappings. Replace these values with real MySQL account
  names in your environment.
*/
INSERT INTO user_customer_access (mysql_user_name, customer_id)
VALUES
    ('app_customer_1', 1),
    ('app_customer_2', 2),
    ('auditor_user', 1),
    ('auditor_user', 2),
    ('auditor_user', 3);

-------------------------------------------------
-- Region: 1. Row-Filtering View
-------------------------------------------------
/*
  1.1 Filter rows based on the current MySQL login name.
  USER() returns a value such as 'user_name@host_name', so the
  account name is extracted with SUBSTRING_INDEX().
*/
CREATE SQL SECURITY INVOKER VIEW vw_orders_for_current_user AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.amount
FROM secured_orders AS o
INNER JOIN user_customer_access AS uca
    ON uca.customer_id = o.customer_id
WHERE uca.mysql_user_name = SUBSTRING_INDEX(USER(), '@', 1);

-------------------------------------------------
-- Region: 2. Testing the Pattern
-------------------------------------------------
/*
  2.1 Show the current connected account context.
*/
SELECT
    USER() AS connected_user,
    CURRENT_USER() AS effective_user;

/*
  2.2 Query through the filtered view.
  In production, users should receive SELECT on the view and no
  direct SELECT privilege on the base table.
*/
SELECT *
FROM vw_orders_for_current_user;

-------------------------------------------------
-- Region: 3. Administrative Review Queries
-------------------------------------------------
/*
  3.1 Review user-to-customer mappings.
*/
SELECT *
FROM user_customer_access
ORDER BY mysql_user_name, customer_id;

/*
  3.2 Review all orders from an administrative session.
*/
SELECT *
FROM secured_orders
ORDER BY order_id;

-------------------------------------------------
-- Region: 4. Operational Notes
-------------------------------------------------
/*
  4.1 This is not a native policy engine. The security boundary
      comes from privileges:
      - Grant SELECT on vw_orders_for_current_user
      - Do not grant SELECT on secured_orders to ordinary users
      - Maintain user_customer_access centrally
*/

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------