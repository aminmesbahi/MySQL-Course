/**************************************************************
 * MySQL 8.0 Security Tutorial – Part 1
 * This script demonstrates core security features
 * in MySQL 8.0, including:
 * - Creating logins and users with password policies.
 * - Role-based access control (RBAC) with MySQL roles.
 * - Object-level and column-level privileges.
 * - Authentication plugins (caching_sha2_password, etc.).
 * - Audit logging via the general log and audit plugin.
 * - Password validation and account locking.
 * - User attribute metadata.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
/*
  Run as a user with SYSTEM_USER privilege (e.g., root or an admin account).
  Most statements in this file require the SUPER or SYSTEM_USER privilege.
*/
USE mysql;

-------------------------------------------------
-- Region: 1. Creating Users with Password Policies
-------------------------------------------------
/*
  1.1 Create a user with the recommended caching_sha2_password plugin
       (default in MySQL 8.0) and explicit password expiry.

  Replace 'StrongPassword123!' with a compliant password in real deployments.
*/
DROP USER IF EXISTS 'app_user'@'localhost';

CREATE USER 'app_user'@'localhost'
    IDENTIFIED WITH caching_sha2_password BY 'StrongPassword123!'
    PASSWORD EXPIRE INTERVAL 90 DAY
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 1;        -- lock for 1 day after 5 failed attempts

/*
  1.2 Create an admin user with connection limits.
*/
DROP USER IF EXISTS 'db_admin'@'%';

CREATE USER 'db_admin'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'AdminPassword456!'
    WITH MAX_CONNECTIONS_PER_HOUR 100
         MAX_USER_CONNECTIONS 10;

/*
  1.3 Show user account details from mysql.user.
*/
SELECT
    User,
    Host,
    plugin,
    password_expired,
    account_locked,
    Password_lifetime
FROM mysql.user
WHERE User IN ('app_user', 'db_admin');

-------------------------------------------------
-- Region: 2. Role-Based Access Control (RBAC)
-------------------------------------------------
/*
  2.1 Create application roles that group related privileges.
*/
DROP ROLE IF EXISTS 'app_read_role';
DROP ROLE IF EXISTS 'app_write_role';
DROP ROLE IF EXISTS 'app_admin_role';

CREATE ROLE 'app_read_role';
CREATE ROLE 'app_write_role';
CREATE ROLE 'app_admin_role';

/*
  2.2 Grant object-level privileges to roles.
       Assumes a database named mysql_course exists.
*/
GRANT SELECT ON mysql_course.* TO 'app_read_role';

GRANT SELECT, INSERT, UPDATE, DELETE
    ON mysql_course.*
    TO 'app_write_role';

GRANT ALL PRIVILEGES ON mysql_course.* TO 'app_admin_role';

/*
  2.3 Assign roles to users.
*/
GRANT 'app_read_role'  TO 'app_user'@'localhost';
GRANT 'app_write_role' TO 'app_user'@'localhost';
GRANT 'app_admin_role' TO 'db_admin'@'%';

/*
  2.4 Set default active roles so users do not need to call SET ROLE manually.
*/
ALTER USER 'app_user'@'localhost'
    DEFAULT ROLE 'app_read_role', 'app_write_role';

ALTER USER 'db_admin'@'%'
    DEFAULT ROLE 'app_admin_role';

/*
  2.5 Inspect assigned roles.
*/
SELECT * FROM mysql.role_edges
WHERE TO_USER IN ('app_user', 'db_admin');

-------------------------------------------------
-- Region: 3. Column-Level Privileges
-------------------------------------------------
/*
  3.1 Grant read access only to non-sensitive columns on a hypothetical table.
       Column-level GRANT restricts SELECT to specific columns.
*/
USE mysql_course;

DROP TABLE IF EXISTS employees;

CREATE TABLE employees
(
    employee_id  INT          PRIMARY KEY AUTO_INCREMENT,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(100) NOT NULL,
    salary       DECIMAL(10,2),
    ssn          CHAR(11)             -- sensitive column
) ENGINE = InnoDB;

INSERT INTO employees (first_name, last_name, email, salary, ssn)
VALUES
    ('Alice', 'Johnson', 'alice@example.com', 85000.00, '123-45-6789'),
    ('Bob',   'Smith',   'bob@example.com',   72000.00, '987-65-4321');

/*
  3.2 Restrict the reporting user to non-sensitive columns only.
*/
DROP USER IF EXISTS 'reporter'@'localhost';
CREATE USER 'reporter'@'localhost'
    IDENTIFIED WITH caching_sha2_password BY 'ReportPass789!';

GRANT SELECT (employee_id, first_name, last_name, email)
    ON mysql_course.employees
    TO 'reporter'@'localhost';

/*
  3.3 Show effective grants for the reporter user.
*/
SHOW GRANTS FOR 'reporter'@'localhost';

-------------------------------------------------
-- Region: 4. Authentication Plugins
-------------------------------------------------
/*
  4.1 List all available authentication plugins.
*/
SELECT PLUGIN_NAME, PLUGIN_STATUS, PLUGIN_TYPE
FROM INFORMATION_SCHEMA.PLUGINS
WHERE PLUGIN_TYPE = 'AUTHENTICATION';

/*
  4.2 Create a user with the mysql_native_password plugin
       (legacy compatibility; caching_sha2_password is preferred).
*/
DROP USER IF EXISTS 'legacy_user'@'localhost';

CREATE USER 'legacy_user'@'localhost'
    IDENTIFIED WITH mysql_native_password BY 'LegacyPass!1';

/*
  4.3 Migrate a native password user to caching_sha2_password.
*/
ALTER USER 'legacy_user'@'localhost'
    IDENTIFIED WITH caching_sha2_password BY 'UpgradedPass!2';

/*
  4.4 Create a user authenticated by an X.509 client certificate
       (requires server-side SSL configuration).
*/
-- DROP USER IF EXISTS 'cert_user'@'%';
-- CREATE USER 'cert_user'@'%'
--     IDENTIFIED WITH caching_sha2_password BY ''
--     REQUIRE X509;

-------------------------------------------------
-- Region: 5. Password Validation Policy
-------------------------------------------------
/*
  5.1 Enable the validate_password component (requires INSTALL COMPONENT once).
*/
-- INSTALL COMPONENT 'file://component_validate_password';

/*
  5.2 Inspect current validation settings.
*/
SHOW VARIABLES LIKE 'validate_password%';

/*
  5.3 Tighten the policy at runtime (requires SYSTEM_VARIABLES_ADMIN).
*/
-- SET GLOBAL validate_password.policy         = 'STRONG';
-- SET GLOBAL validate_password.length         = 12;
-- SET GLOBAL validate_password.mixed_case_count = 1;
-- SET GLOBAL validate_password.number_count    = 1;
-- SET GLOBAL validate_password.special_char_count = 1;

-------------------------------------------------
-- Region: 6. Account Locking and Unlocking
-------------------------------------------------
/*
  6.1 Lock an account immediately (e.g., when an employee leaves).
*/
ALTER USER 'app_user'@'localhost' ACCOUNT LOCK;

/*
  6.2 Verify the lock.
*/
SELECT User, Host, account_locked
FROM mysql.user
WHERE User = 'app_user';

/*
  6.3 Unlock the account when appropriate.
*/
ALTER USER 'app_user'@'localhost' ACCOUNT UNLOCK;

-------------------------------------------------
-- Region: 7. General Query Log and Audit
-------------------------------------------------
/*
  7.1 The general log records every query received by the server.
       Enable it temporarily for auditing; disable in production to
       avoid performance overhead.
*/
SHOW VARIABLES LIKE 'general_log%';

-- SET GLOBAL general_log    = 'ON';
-- SET GLOBAL general_log_file = '/var/log/mysql/general.log';

/*
  7.2 For production auditing, install the MySQL Enterprise Audit plugin
       or the community audit_log plugin from Percona.
       The variable below shows whether the plugin is already active.
*/
SELECT PLUGIN_NAME, PLUGIN_STATUS
FROM INFORMATION_SCHEMA.PLUGINS
WHERE PLUGIN_NAME LIKE 'audit%';

-------------------------------------------------
-- Region: 8. Revoking Privileges and Cleanup
-------------------------------------------------
/*
  8.1 Revoke a specific privilege from a role.
*/
REVOKE DELETE ON mysql_course.* FROM 'app_write_role';

/*
  8.2 Revoke all privileges from a user and drop the account.
*/
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'reporter'@'localhost';
DROP USER 'reporter'@'localhost';

/*
  8.3 Drop the demo roles.
*/
DROP ROLE IF EXISTS 'app_read_role';
DROP ROLE IF EXISTS 'app_write_role';
DROP ROLE IF EXISTS 'app_admin_role';

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
