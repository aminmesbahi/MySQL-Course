/**************************************************************
 * MySQL 8.0 XML Tutorial
 * Description: This script demonstrates working with XML in
 *              MySQL by storing XML documents as text and using
 *              the built-in XPath helper functions ExtractValue()
 *              and UpdateXML().
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS product_xml;

CREATE TABLE product_xml
(
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_details LONGTEXT NOT NULL
) ENGINE = InnoDB;

INSERT INTO product_xml (product_id, product_name, product_details)
VALUES
    (1, 'Product A', '<Product><Category>Electronics</Category><Price>100</Price></Product>'),
    (2, 'Product B', '<Product><Category>Home Appliances</Category><Price>200</Price></Product>');

-------------------------------------------------
-- Region: 1. Extracting XML Values
-------------------------------------------------
/*
  1.1 Extract scalar values using XPath expressions.
*/
SELECT
    product_id,
    ExtractValue(product_details, '/Product/Category') AS category_name,
    ExtractValue(product_details, '/Product/Price') AS product_price
FROM product_xml;

/*
  1.2 Count matching XML elements.
*/
SELECT
    product_id,
    ExtractValue(product_details, 'count(/Product/Price)') AS price_node_count
FROM product_xml;

-------------------------------------------------
-- Region: 2. Updating XML Content
-------------------------------------------------
/*
  2.1 Replace the Price node for Product A.
*/
UPDATE product_xml
SET product_details = UpdateXML(product_details, '/Product/Price', '<Price>150</Price>')
WHERE product_id = 1;

-------------------------------------------------
-- Region: 3. Reviewing Updated XML
-------------------------------------------------
/*
  3.1 Return the updated XML and extracted values side by side.
*/
SELECT
    product_id,
    product_name,
    product_details,
    ExtractValue(product_details, '/Product/Price') AS updated_price
FROM product_xml;

-------------------------------------------------
-- Region: 4. XML Notes
-------------------------------------------------
/*
  4.1 MySQL does not provide a native XML data type like SQL Server.
      XML is usually stored as text and validated in the application layer.

  4.2 The repository data folder also contains books.xml for import and
      experimentation outside this script.
*/

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------