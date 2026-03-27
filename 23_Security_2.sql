/**************************************************************
 * MySQL 8.0 Security Tutorial – Part 2
 * This script demonstrates advanced security features
 * in MySQL 8.0, including:
 * - InnoDB tablespace-level encryption (data at rest).
 * - Encrypted connections with TLS/SSL.
 * - Dynamic data masking with MySQL Enterprise or
 *   masking function alternatives.
 * - Row-level access patterns (VIEW + DEFINER).
 * - Transparent Data Encryption via keyring components.
 * - User attribute metadata and proxy users.
 * - Privilege escalation prevention.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
/*
  Run as root or an account with SYSTEM_USER and SUPER privileges.
*/
USE mysql_course;

-------------------------------------------------
-- Region: 1. InnoDB Data-at-Rest Encryption
-------------------------------------------------
/*
  1.1 Enable the keyring component (runs once at server startup via
       early-plugin-load or component installation).
       The community keyring_file component stores keys in a local file.
*/
-- INSTALL COMPONENT 'file://component_keyring_file';

/*
  1.2 Verify the active keyring.
*/
SELECT PLUGIN_NAME, PLUGIN_STATUS
FROM INFORMATION_SCHEMA.PLUGINS
WHERE PLUGIN_NAME LIKE 'keyring%';

/*
  1.3 Create an encrypted InnoDB table.
       ENCRYPTION = 'Y' encrypts the tablespace using the master key.
*/
DROP TABLE IF EXISTS sensitive_data;

CREATE TABLE sensitive_data
(
    record_id   INT         PRIMARY KEY AUTO_INCREMENT,
    customer_id INT         NOT NULL,
    credit_card CHAR(16)    NOT NULL,
    notes       VARCHAR(255)
) ENGINE = InnoDB ENCRYPTION = 'Y';

INSERT INTO sensitive_data (customer_id, credit_card, notes)
VALUES
    (101, '4111111111111111', 'Test card – Visa'),
    (102, '5500005555555559', 'Test card – MasterCard');

/*
  1.4 Verify encryption status via INFORMATION_SCHEMA.
*/
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    CREATE_OPTIONS
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'mysql_course'
  AND TABLE_NAME   = 'sensitive_data';

/*
  1.5 Rotate the master encryption key.
       This re-encrypts all tablespace keys without touching the data.
*/
-- ALTER INSTANCE ROTATE INNODB MASTER KEY;

-------------------------------------------------
-- Region: 2. Encrypted Connections (TLS/SSL)
-------------------------------------------------
/*
  2.1 Check whether the server has TLS enabled.
*/
SHOW VARIABLES LIKE 'have_ssl';
SHOW VARIABLES LIKE 'ssl_%';

/*
  2.2 Check the TLS status of the current session.
*/
SHOW STATUS LIKE 'Ssl_cipher';

/*
  2.3 Require TLS for a specific user account.
*/
DROP USER IF EXISTS 'secure_user'@'%';

CREATE USER 'secure_user'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'SecurePass!99'
    REQUIRE SSL;

/*
  2.4 Require a specific TLS cipher or X.509 certificate.
*/
DROP USER IF EXISTS 'cert_user'@'%';

CREATE USER 'cert_user'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'CertPass!99'
    REQUIRE X509;

/*
  2.5 Verify connection requirements per user.
*/
SELECT User, Host, ssl_type, ssl_cipher, x509_issuer
FROM mysql.user
WHERE User IN ('secure_user', 'cert_user');

-------------------------------------------------
-- Region: 3. Data Masking Alternatives
-------------------------------------------------
/*
  3.1 MySQL Enterprise Edition provides the data_masking plugin.
       The community equivalent is to use views or generated columns
       that apply masking expressions.

  3.2 Create a masking view over the employees table from lesson 22.
       Sensitive columns (ssn, salary) are either hidden or masked.
*/
DROP VIEW IF EXISTS v_employees_masked;

CREATE VIEW v_employees_masked AS
SELECT
    employee_id,
    first_name,
    last_name,
    email,
    -- Show only last 4 digits of SSN
    CONCAT('***-**-', RIGHT(ssn, 4))    AS ssn_masked,
    -- Mask salary with a salary band instead of actual value
    CASE
        WHEN salary < 50000  THEN 'Band A'
        WHEN salary < 100000 THEN 'Band B'
        ELSE                      'Band C'
    END                                  AS salary_band
FROM employees;

SELECT * FROM v_employees_masked;

/*
  3.3 Enterprise masking functions reference (available with
       MySQL Enterprise / MySQL HeatWave).
       These functions are listed here for documentation; run them
       only if the plugin is installed.
*/
-- SELECT mask_pan('4111111111111111');          -- mask a payment card number
-- SELECT mask_ssn('123-45-6789');               -- mask a US SSN
-- SELECT gen_rnd_email();                       -- generate a random email
-- SELECT gen_rnd_us_phone();                    -- generate a random phone

-------------------------------------------------
-- Region: 4. Row-Level Access Patterns (DEFINER Views)
-------------------------------------------------
/*
  4.1 MySQL does not have native row-level security policies, but the
       same effect can be achieved with SQL SECURITY DEFINER views that
       filter rows based on the CLIENT information or a user mapping table.

  4.2 Create a user-to-department mapping table.
*/
DROP TABLE IF EXISTS user_department_map;

CREATE TABLE user_department_map
(
    mysql_user  VARCHAR(100) NOT NULL,
    department  VARCHAR(100) NOT NULL,
    PRIMARY KEY (mysql_user, department)
) ENGINE = InnoDB;

INSERT INTO user_department_map (mysql_user, department)
VALUES
    ('app_user', 'IT'),
    ('app_user', 'HR');

DROP TABLE IF EXISTS emp_data;

CREATE TABLE emp_data
(
    emp_id     INT          PRIMARY KEY AUTO_INCREMENT,
    emp_name   VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    salary     DECIMAL(10,2)
) ENGINE = InnoDB;

INSERT INTO emp_data (emp_name, department, salary)
VALUES
    ('Alice', 'IT',      90000),
    ('Bob',   'Finance', 80000),
    ('Carol', 'HR',      75000),
    ('Dave',  'IT',      95000);

/*
  4.3 Create a DEFINER view that restricts rows to the calling user's
       allowed departments.  SQL SECURITY DEFINER executes as the view
       owner, so the underlying table does not need to be directly
       accessible to the calling user.
*/
DROP VIEW IF EXISTS v_my_employees;

CREATE DEFINER = CURRENT_USER
SQL SECURITY DEFINER
VIEW v_my_employees AS
SELECT e.*
FROM emp_data         e
JOIN user_department_map m
  ON m.department = e.department
 AND m.mysql_user = CURRENT_USER();

/*
  4.4 Test the view from the current session.
*/
SELECT * FROM v_my_employees;

-------------------------------------------------
-- Region: 5. Privilege Escalation Prevention
-------------------------------------------------
/*
  5.1 Grant only required privileges — avoid GRANT OPTION unless necessary.
*/
DROP USER IF EXISTS 'restricted_user'@'localhost';

CREATE USER 'restricted_user'@'localhost'
    IDENTIFIED WITH caching_sha2_password BY 'RestrictedP@ss1';

GRANT SELECT, INSERT ON mysql_course.emp_data TO 'restricted_user'@'localhost';
-- No UPDATE, DELETE, or GRANT OPTION intentionally.

/*
  5.2 Show effective grants.
*/
SHOW GRANTS FOR 'restricted_user'@'localhost';

/*
  5.3 Restrict the user to operate only within mysql_course.
       Granting global (*.*)  privileges is intentionally omitted.
*/

-------------------------------------------------
-- Region: 6. Proxy Users
-------------------------------------------------
/*
  6.1 A proxy user forwards authentication to a base user.
       Useful for mapping OS accounts to database roles without
       storing individual passwords in MySQL.
*/
DROP USER IF EXISTS 'base_account'@'%';
DROP USER IF EXISTS ''@'%';

CREATE USER 'base_account'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'BaseAccP@ss1';

GRANT ALL ON mysql_course.* TO 'base_account'@'%';

/*
  6.2 Create an anonymous proxy user that maps to base_account.
       Requires the PROXY privilege.
*/
-- CREATE USER ''@'%' IDENTIFIED WITH auth_socket AS 'base_account';
-- GRANT PROXY ON 'base_account'@'%' TO ''@'%';

-------------------------------------------------
-- Region: 7. Cleanup
-------------------------------------------------
DROP USER IF EXISTS 'secure_user'@'%';
DROP USER IF EXISTS 'cert_user'@'%';
DROP USER IF EXISTS 'restricted_user'@'localhost';
DROP TABLE IF EXISTS sensitive_data;
DROP TABLE IF EXISTS emp_data;
DROP TABLE IF EXISTS user_department_map;
DROP VIEW  IF EXISTS v_employees_masked;
DROP VIEW  IF EXISTS v_my_employees;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
