/**************************************************************
 * MySQL 8.0: Regular Expressions
 * This script demonstrates MySQL 8.0's four REGEXP
 * functions (powered by the ICU library):
 *  1. REGEXP_LIKE   – boolean test: does the string match?
 *  2. REGEXP_INSTR  – position of first/nth match.
 *  3. REGEXP_SUBSTR – extract a matching substring.
 *  4. REGEXP_REPLACE – replace matches with a substitution.
 * Practical examples include data validation (email, phone,
 * postal codes), data masking, and data cleansing.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS raw_data;

CREATE TABLE contacts
(
    contact_id   INT          PRIMARY KEY AUTO_INCREMENT,
    full_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(200) NOT NULL,
    phone        VARCHAR(30)  NOT NULL,
    postal_code  VARCHAR(20)  NOT NULL,
    notes        TEXT
) ENGINE = InnoDB;

CREATE TABLE raw_data
(
    raw_id  INT          PRIMARY KEY AUTO_INCREMENT,
    content TEXT         NOT NULL
) ENGINE = InnoDB;

INSERT INTO contacts (full_name, email, phone, postal_code, notes) VALUES
    ('Alice Johnson', 'alice@example.com',   '+1-202-555-0101', '10001',    'VIP customer'),
    ('Bob Smith',     'bob@invalid',         '202.555.0102',    'AB1 2CD',  NULL),
    ('Carol White',   'carol@example.co.uk', '+44 20 7946 0958','SW1A 1AA', 'UK office'),
    ('Dave Brown',    'dave@EXAMPLE.COM',    '5550103',          '90210',   'LA contact'),
    ('Eve Davis',     'not-an-email',        '+49 30 12345678',  '10115',   'Berlin');

INSERT INTO raw_data (content) VALUES
    ('Order ref: ORD-2024-0001 total $250.00'),
    ('Delivery to 42 Maple Street, New York, NY 10001'),
    ('Call us at 1-800-FLOWERS or (800) 356-9377'),
    ('Please verify: order #A12345 and #B67890');

-------------------------------------------------
-- Region: 1. REGEXP_LIKE – Pattern Matching Test
-------------------------------------------------
/*
  1.1  REGEXP_LIKE(expr, pattern [, match_type]) returns 1 (TRUE) if
       expr matches the ICU regular expression in pattern.

  match_type flags:
      c  – case-sensitive (default for non-CI collations)
      i  – case-insensitive
      m  – multi-line (^ and $ match start/end of each line)
      n  – '.' matches newline
      x  – extended mode (whitespace ignored, # comments allowed)
*/

-- Basic pattern: does the email look valid?
SELECT full_name, email,
       REGEXP_LIKE(email, '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$') AS is_valid_email
FROM   contacts;

-- Case-insensitive flag
SELECT full_name, email,
       REGEXP_LIKE(email, '@EXAMPLE\\.COM$', 'i') AS is_example_domain
FROM   contacts;

-- Filter rows using REGEXP_LIKE in WHERE
SELECT full_name, phone
FROM   contacts
WHERE  REGEXP_LIKE(phone, '^\\+[0-9]');    -- starts with international code

-------------------------------------------------
-- Region: 2. REGEXP_INSTR – Find Match Position
-------------------------------------------------
/*
  2.1  REGEXP_INSTR(expr, pattern [, pos [, occurrence [, return_option [, match_type]]]])
       Returns the character position of the first (or nth) match.
       return_option = 0 (default): position of the start of the match.
       return_option = 1           : position of the first character AFTER the match.
       Returns 0 if no match.
*/

-- Find where the domain part starts in an email
SELECT full_name, email,
       REGEXP_INSTR(email, '@') AS at_position
FROM   contacts;

-- Find second occurrence of a digit group in notes
SELECT content,
       REGEXP_INSTR(content, '[0-9]+', 1, 1) AS first_number_pos,
       REGEXP_INSTR(content, '[0-9]+', 1, 2) AS second_number_pos
FROM   raw_data;

-- Position after the match (useful for SUBSTRING)
SELECT content,
       REGEXP_INSTR(content, 'ORD-[0-9-]+', 1, 1, 0) AS match_start,
       REGEXP_INSTR(content, 'ORD-[0-9-]+', 1, 1, 1) AS match_end
FROM   raw_data;

-------------------------------------------------
-- Region: 3. REGEXP_SUBSTR – Extract Matching Text
-------------------------------------------------
/*
  3.1  REGEXP_SUBSTR(expr, pattern [, pos [, occurrence [, match_type [, group]]]])
       Returns the matched substring, or NULL if there is no match.
       The optional 'group' parameter (MySQL 8.0.16+) returns a specific
       capture group number.
*/

-- Extract the domain from email addresses
SELECT full_name, email,
       REGEXP_SUBSTR(email, '[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$') AS domain
FROM   contacts;

-- Extract a US ZIP code (5 digits)
SELECT full_name, postal_code,
       REGEXP_SUBSTR(postal_code, '^[0-9]{5}$') AS us_zip        -- NULL for non-US
FROM   contacts;

-- Extract order numbers from raw data
SELECT content,
       REGEXP_SUBSTR(content, 'ORD-[0-9-]+')           AS order_ref,
       REGEXP_SUBSTR(content, '#[A-Z][0-9]+', 1, 1)    AS first_item_ref,
       REGEXP_SUBSTR(content, '#[A-Z][0-9]+', 1, 2)    AS second_item_ref
FROM   raw_data;

-- Use capture groups (MySQL 8.0.16+): extract area code from phone
SELECT full_name, phone,
       REGEXP_SUBSTR(phone, '\\+([0-9]+)', 1, 1, '', 1) AS country_code
FROM   contacts
WHERE  REGEXP_LIKE(phone, '^\\+');

-------------------------------------------------
-- Region: 4. REGEXP_REPLACE – Replace Matches
-------------------------------------------------
/*
  4.1  REGEXP_REPLACE(expr, pattern, replacement [, pos [, occurrence [, match_type]]])
       Replaces matches with the replacement string.
       Back-references in the replacement: $1, $2, ... for capture groups.
       occurrence = 0 replaces all matches (default).
       occurrence = N replaces only the Nth match.
*/

-- Normalise phone numbers: remove non-digit characters
SELECT full_name, phone,
       REGEXP_REPLACE(phone, '[^0-9]', '') AS digits_only
FROM   contacts;

-- Mask middle digits of a credit-card or phone number
SELECT full_name,
       REGEXP_REPLACE(phone, '(\\d{3})[\\-\\.](\\d{3})(.*)', '$1-XXX$3') AS masked_phone
FROM   contacts;

-- Remove HTML tags from a string
SELECT REGEXP_REPLACE('<b>Hello</b> <i>World</i>', '<[^>]+>', '') AS stripped;

-- Trim multiple internal spaces
SELECT REGEXP_REPLACE('too   many    spaces here', '  +', ' ') AS cleaned;

-- Replace only the second occurrence
SELECT REGEXP_REPLACE('cat cat cat', 'cat', 'dog', 1, 2) AS second_replaced;

-------------------------------------------------
-- Region: 5. Data Validation with REGEXP_LIKE
-------------------------------------------------
/*
  5.1  Combine REGEXP_LIKE with INSERT validation in a stored procedure
       or CHECK constraint (MySQL 8.0.16+) to enforce data quality.
*/
DROP PROCEDURE IF EXISTS ValidateContact;

DELIMITER //

CREATE PROCEDURE ValidateContact
(
    IN p_name   VARCHAR(100),
    IN p_email  VARCHAR(200),
    IN p_phone  VARCHAR(30)
)
BEGIN
    IF NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid email address format.';
    END IF;

    IF NOT REGEXP_LIKE(p_phone, '^\\+?[0-9][\\s\\-.()0-9]{6,}$') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid phone number format.';
    END IF;

    INSERT INTO contacts (full_name, email, phone, postal_code)
    VALUES (p_name, p_email, p_phone, '00000');
END //

DELIMITER ;

-- Valid
CALL ValidateContact('Frank Green', 'frank@example.com', '+1-800-555-1234');

-- Invalid email (raises error)
-- CALL ValidateContact('Ghost User', 'not-email', '+1-800-555-0000');

SELECT full_name, email FROM contacts WHERE full_name = 'Frank Green';

-------------------------------------------------
-- Region: 6. REGEXP in CHECK Constraints (MySQL 8.0.16+)
-------------------------------------------------
/*
  6.1  A CHECK constraint using REGEXP_LIKE enforces a pattern at the
       storage engine level without needing a trigger or procedure.
*/
DROP TABLE IF EXISTS validated_users;

CREATE TABLE validated_users
(
    user_id    INT          PRIMARY KEY AUTO_INCREMENT,
    username   VARCHAR(50)  NOT NULL,
    email      VARCHAR(200) NOT NULL,
    CONSTRAINT chk_email
        CHECK (REGEXP_LIKE(email, '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$')),
    CONSTRAINT chk_username
        CHECK (REGEXP_LIKE(username, '^[A-Za-z0-9_]{3,20}$'))
) ENGINE = InnoDB;

INSERT INTO validated_users (username, email) VALUES ('john_doe', 'john@example.com');

-- Violates email constraint:
-- INSERT INTO validated_users (username, email) VALUES ('jane', 'not-valid');

SELECT * FROM validated_users;

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP PROCEDURE IF EXISTS ValidateContact;
DROP TABLE    IF EXISTS validated_users;
DROP TABLE    IF EXISTS raw_data;
DROP TABLE    IF EXISTS contacts;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
