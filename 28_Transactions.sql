/**************************************************************
 * MySQL 8.0 Transactions Tutorial
 * This script demonstrates transaction management
 * in MySQL 8.0 using InnoDB, including:
 * - Basic START TRANSACTION / COMMIT / ROLLBACK.
 * - SAVEPOINT and ROLLBACK TO SAVEPOINT.
 * - Nested savepoints.
 * - Implicit transactions (autocommit).
 * - Detached / distributed transactions with XA.
 * - Error handling inside transactions using EXIT HANDLER.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization and Sample Tables
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts
(
    account_id     INT           PRIMARY KEY AUTO_INCREMENT,
    account_holder VARCHAR(100)  NOT NULL,
    balance        DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO accounts (account_id, account_holder, balance)
VALUES
    (1, 'Alice',   1000.00),
    (2, 'Bob',     1500.00),
    (3, 'Charlie', 2000.00);

-------------------------------------------------
-- Region: 1. Basic Transaction with COMMIT / ROLLBACK
-------------------------------------------------
/*
  1.1 Transfer $200 from Alice to Bob.
       Check Alice's balance after the debit; commit if non-negative,
       otherwise roll back.
*/
START TRANSACTION;

UPDATE accounts SET balance = balance - 200.00 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 200.00 WHERE account_id = 2;

-- Verify the intermediate state (only visible within this transaction)
SELECT account_id, account_holder, balance FROM accounts;

-- Commit if Alice's balance remains non-negative
-- In a stored procedure you would test @@ROWCOUNT / a SELECT result;
-- here we inspect inline:
SELECT balance INTO @alice_balance FROM accounts WHERE account_id = 1;

-- MySQL does not support inline IF in a plain SQL script the same way
-- T-SQL does; wrap the decision in a BEGIN...END block or a procedure.
-- Shown as a procedure call in Region 5.
COMMIT;

-------------------------------------------------
-- Region: 2. Rolling Back on Error
-------------------------------------------------
/*
  2.1 Demonstrate ROLLBACK when an error is detected.
*/
START TRANSACTION;

UPDATE accounts SET balance = balance - 5000.00 WHERE account_id = 2;  -- overdraft

SET @bob_balance = (SELECT balance FROM accounts WHERE account_id = 2);

-- Bob cannot go below zero – roll back the bad debit
ROLLBACK;

SELECT account_id, account_holder, balance FROM accounts;

-------------------------------------------------
-- Region: 3. Transaction with SAVEPOINT
-------------------------------------------------
/*
  3.1 SAVEPOINT lets you roll back a portion of a transaction without
      abandoning the whole unit of work.
*/
START TRANSACTION;

SAVEPOINT sp_after_debit;

UPDATE accounts SET balance = balance - 500.00 WHERE account_id = 2;
UPDATE accounts SET balance = balance + 500.00 WHERE account_id = 3;

-- If Bob's balance is negative, roll back only to the savepoint
SET @bob_bal = (SELECT balance FROM accounts WHERE account_id = 2);

-- Simulating an insufficient-funds check:
-- ROLLBACK TO SAVEPOINT sp_after_debit;    -- uncomment to test rollback path

COMMIT;

SELECT account_holder, balance FROM accounts;

-------------------------------------------------
-- Region: 4. Autocommit Behaviour
-------------------------------------------------
/*
  4.1 With autocommit ON (MySQL default), each statement is its own
      transaction.  Disable it to group statements manually.
*/
SHOW VARIABLES LIKE 'autocommit';

-- Disable autocommit for the session
SET autocommit = 0;

UPDATE accounts SET balance = balance + 100 WHERE account_id = 1;
-- At this point the change is pending in the current transaction.
-- Another session cannot see it yet (with default READ COMMITTED or
-- REPEATABLE READ isolation).

ROLLBACK;   -- discard the pending change

SET autocommit = 1;   -- restore default

-- Confirm balance is unchanged
SELECT account_holder, balance FROM accounts WHERE account_id = 1;

-------------------------------------------------
-- Region: 5. Transaction Decision Inside a Stored Procedure
-------------------------------------------------
/*
  5.1 wrap the commit/rollback decision inside a procedure so it can
      use IF logic together with a transaction.
*/
DROP PROCEDURE IF EXISTS TransferFunds;

DELIMITER //

CREATE PROCEDURE TransferFunds(
    IN p_from_id INT,
    IN p_to_id   INT,
    IN p_amount  DECIMAL(10,2)
)
BEGIN
    DECLARE v_from_balance DECIMAL(10,2);
    DECLARE v_sqlstate CHAR(5)  DEFAULT '00000';
    DECLARE v_message  TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_message  = MESSAGE_TEXT;
        ROLLBACK;
        SELECT v_sqlstate AS sqlstate, v_message AS error_message;
    END;

    START TRANSACTION;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_id;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_id;

    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_id = p_from_id;

    IF v_from_balance < 0 THEN
        ROLLBACK;
        SELECT 'Insufficient funds – transaction rolled back.' AS result;
    ELSE
        COMMIT;
        SELECT 'Transfer committed successfully.' AS result;
    END IF;
END //

DELIMITER ;

/*
  5.2 Valid transfer: Bob to Charlie.
*/
CALL TransferFunds(2, 3, 300.00);
SELECT account_holder, balance FROM accounts;

/*
  5.3 Invalid transfer: debit more than Alice has.
*/
CALL TransferFunds(1, 3, 9999.00);
SELECT account_holder, balance FROM accounts;

-------------------------------------------------
-- Region: 6. Nested Savepoints
-------------------------------------------------
/*
  6.1 You can set multiple named savepoints and roll back selectively.
*/
START TRANSACTION;

UPDATE accounts SET balance = balance + 50 WHERE account_id = 1; -- step 1
SAVEPOINT sp_step1;

UPDATE accounts SET balance = balance + 50 WHERE account_id = 2; -- step 2
SAVEPOINT sp_step2;

UPDATE accounts SET balance = balance + 50 WHERE account_id = 3; -- step 3

-- Undo only step 3 and step 2; keep step 1
ROLLBACK TO SAVEPOINT sp_step1;

-- Verify: Alice +50, Bob unchanged, Charlie unchanged
SELECT account_holder, balance FROM accounts;

COMMIT;

-------------------------------------------------
-- Region: 7. XA (Distributed) Transactions
-------------------------------------------------
/*
  7.1 XA transactions coordinate a two-phase commit across multiple
      MySQL instances or other XA-compliant resource managers.
      The XID is a tuple (gtrid, bqual [, formatID]).
*/
XA START 'xa_txn_001';

UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;

XA END 'xa_txn_001';

XA PREPARE 'xa_txn_001';

-- At this point the transaction is prepared; the coordinator decides.
-- Commit:
XA COMMIT 'xa_txn_001';

-- To roll back a prepared XA transaction instead:
-- XA ROLLBACK 'xa_txn_001';

/*
  7.2 List prepared XA transactions (useful for recovery after a crash).
*/
XA RECOVER;

-------------------------------------------------
-- Region: 8. Cleanup
-------------------------------------------------
DROP PROCEDURE IF EXISTS TransferFunds;
DROP TABLE    IF EXISTS accounts;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
