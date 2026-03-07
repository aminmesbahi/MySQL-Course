/**************************************************************
 * MySQL 8.0 JSON Tutorial
 * Description: This script demonstrates working with native JSON
 *              data in MySQL, including validation, extraction,
 *              updates, generated columns, JSON_TABLE, and JSON
 *              constructors.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS orders;

CREATE TABLE orders
(
    order_id INT PRIMARY KEY,
    order_details JSON NOT NULL,
    customer_name VARCHAR(100)
        GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(order_details, '$.Customer'))) STORED,
    INDEX ix_orders_customer_name (customer_name)
) ENGINE = InnoDB;

INSERT INTO orders (order_id, order_details)
VALUES
    (1, '{"Customer":"John Doe","Items":[{"Product":"Laptop","Quantity":1},{"Product":"Mouse","Quantity":2}]}'),
    (2, '{"Customer":"Jane Smith","Items":[{"Product":"Tablet","Quantity":1},{"Product":"Keyboard","Quantity":1}]}');

-------------------------------------------------
-- Region: 1. Validating and Inspecting JSON
-------------------------------------------------
/*
  1.1 Test JSON validity.
*/
SELECT
    order_id,
    JSON_VALID(order_details) AS is_valid_json
FROM orders;

/*
  1.2 Extract the customer name and items array.
*/
SELECT
    order_id,
    JSON_UNQUOTE(JSON_EXTRACT(order_details, '$.Customer')) AS customer_name,
    JSON_EXTRACT(order_details, '$.Items') AS items_array
FROM orders;

-------------------------------------------------
-- Region: 2. Modifying JSON
-------------------------------------------------
/*
  2.1 Update one property within the JSON document.
*/
UPDATE orders
SET order_details = JSON_SET(order_details, '$.Customer', 'John Smith')
WHERE order_id = 1;

-------------------------------------------------
-- Region: 3. JSON Constructors
-------------------------------------------------
/*
  3.1 Construct a JSON array and object.
*/
SELECT JSON_ARRAY('Laptop', 'Mouse', 'Keyboard') AS products_array;

SELECT JSON_OBJECT('Customer', 'John Doe', 'OrderID', 1) AS order_object;

-------------------------------------------------
-- Region: 4. JSON_TABLE Example
-------------------------------------------------
/*
  4.1 Shred JSON array elements into relational rows.
*/
SELECT
    o.order_id,
    item.product_name,
    item.quantity
FROM orders AS o,
JSON_TABLE(
    o.order_details,
    '$.Items[*]'
    COLUMNS
    (
        product_name VARCHAR(100) PATH '$.Product',
        quantity INT PATH '$.Quantity'
    )
) AS item;

-------------------------------------------------
-- Region: 5. Aggregation Back to JSON
-------------------------------------------------
/*
  5.1 Build a JSON array from relational data.
*/
SELECT JSON_ARRAYAGG(customer_name) AS customers_json
FROM orders;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------