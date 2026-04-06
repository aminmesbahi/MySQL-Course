/**************************************************************
 * MySQL 8.0: Transaction Isolation Levels
 * This script demonstrates all four isolation levels
 * supported by InnoDB and shows the concurrency
 * anomalies each one allows or prevents:
 *  - READ UNCOMMITTED  (allows dirty reads)
 *  - READ COMMITTED    (prevents dirty reads)
 *  - REPEATABLE READ   (MySQL default; prevents non-repeatable reads)
 *  - SERIALIZABLE      (prevents phantom reads)
 * The script also explains the MVCC mechanism that
 * makes READ COMMITTED and REPEATABLE READ lock-free
 * for plain SELECT statements.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS isolation_demo;

CREATE TABLE accounts
(
    account_id INT           PRIMARY KEY AUTO_INCREMENT,
    owner      VARCHAR(50)   NOT NULL,
    balance    DECIMAL(10,2) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE isolation_demo
(
    id    INT         PRIMARY KEY AUTO_INCREMENT,
    value VARCHAR(50) NOT NULL
) ENGINE = InnoDB;

INSERT INTO accounts (owner, balance) VALUES
    ('Alice',  1000.00),
    ('Bob',     500.00);

INSERT INTO isolation_demo (value) VALUES ('initial');

-------------------------------------------------
-- Region: 1. Check and Set the Isolation Level
-------------------------------------------------
/*
  1.1  View the current session and global isolation levels.
       The system variable @@transaction_isolation is the preferred
       name in MySQL 8.0 (@@tx_isolation is a deprecated alias).
*/
SELECT @@global.transaction_isolation  AS global_level,
       @@session.transaction_isolation AS session_level;

/*
  1.2  Change the isolation level for the current session only.
       This setting takes effect for the next transaction.
*/
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT @@session.transaction_isolation AS current_level;

-- Reset to MySQL's default
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

/*
  1.3  Set a single-transaction isolation level (next START TRANSACTION only).
*/
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT @@session.transaction_isolation AS next_txn_level;

-- The transient override is consumed by the next COMMIT/ROLLBACK
START TRANSACTION;
SELECT 'In SERIALIZABLE transaction' AS note;
ROLLBACK;

-- Level reverts to REPEATABLE READ after the transaction ends
SELECT @@session.transaction_isolation AS after_rollback;

-------------------------------------------------
-- Region: 2. READ UNCOMMITTED – Dirty Reads
-------------------------------------------------
/*
  2.1  READ UNCOMMITTED is the most permissive level.
       A transaction can read rows written by another transaction
       that has not yet committed.  This is called a "dirty read".

  Scenario (two connections needed to reproduce live):
    Session A: START TRANSACTION; UPDATE accounts SET balance = 9999 WHERE owner = 'Alice';
    Session B: SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
               SELECT balance FROM accounts WHERE owner = 'Alice';  -- returns 9999
    Session A: ROLLBACK;
    Session B: SELECT balance FROM accounts WHERE owner = 'Alice';  -- now returns 1000 (phantom change)
*/
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;
SELECT balance FROM accounts WHERE owner = 'Alice';   -- may see uncommitted changes from other sessions
ROLLBACK;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-------------------------------------------------
-- Region: 3. READ COMMITTED – No Dirty Reads
-------------------------------------------------
/*
  3.1  READ COMMITTED prevents dirty reads: a transaction only sees rows
       that have been permanently committed.  However, if another
       transaction commits new rows between two reads within the same
       transaction, the second read may produce different results
       (non-repeatable read).

  Scenario:
    Session A: START TRANSACTION; UPDATE accounts SET balance = 1500 WHERE owner = 'Alice'; COMMIT;
    Session B (READ COMMITTED):   -- first read: 1000; second read: 1500  => non-repeatable
*/
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;
SELECT balance FROM accounts WHERE owner = 'Alice';   -- committed snapshot at this point
-- (other sessions can commit in between)
SELECT balance FROM accounts WHERE owner = 'Alice';   -- could differ if another session committed
COMMIT;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-------------------------------------------------
-- Region: 4. REPEATABLE READ – MySQL Default
-------------------------------------------------
/*
  4.1  REPEATABLE READ is InnoDB's default.  The snapshot is taken at
       the first read within a transaction; all subsequent reads in the
       same transaction see the same data, eliminating non-repeatable reads.

  InnoDB achieves this with Multi-Version Concurrency Control (MVCC):
  each transaction reads a consistent snapshot of the undo-log chain
  without acquiring shared locks for plain SELECTs.

  4.2  Phantom reads (new rows inserted by another transaction matching
       a predicate) are mostly prevented in InnoDB due to gap locks and
       next-key locks.
*/
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;
SELECT balance FROM accounts WHERE owner = 'Alice';   -- snapshot established here
-- (other sessions may update and commit Alice's balance)
SELECT balance FROM accounts WHERE owner = 'Alice';   -- always same as first read
COMMIT;

-------------------------------------------------
-- Region: 5. SERIALIZABLE – Strictest Level
-------------------------------------------------
/*
  5.1  SERIALIZABLE converts every plain SELECT into a locking read
       (equivalent to SELECT ... FOR SHARE), preventing phantom reads.
       All transactions execute as if they were run one at a time.
       Use only where absolute consistency is mandatory; it significantly
       reduces concurrency.
*/
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;
SELECT balance FROM accounts;   -- acquires shared locks on all rows read
-- Other sessions cannot insert rows here that would match this range
COMMIT;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-------------------------------------------------
-- Region: 6. Locking Reads: FOR SHARE and FOR UPDATE
-------------------------------------------------
/*
  6.1  Regardless of isolation level you can request explicit locks:
       SELECT ... FOR SHARE  – shared (read) lock; others can read but not write.
       SELECT ... FOR UPDATE – exclusive lock; blocks reads and writes.

  Use FOR UPDATE when you intend to modify the rows immediately after reading.
*/
START TRANSACTION;

SELECT balance
FROM   accounts
WHERE  owner = 'Alice'
FOR UPDATE;                      -- exclusive lock on Alice's row

UPDATE accounts
SET    balance = balance - 100
WHERE  owner  = 'Alice';

COMMIT;

-------------------------------------------------
-- Region: 7. SKIP LOCKED and NOWAIT
-------------------------------------------------
/*
  7.1  SKIP LOCKED skips rows already locked by another transaction.
       Useful for queue-style workloads where multiple workers pick
       distinct "jobs" from the same table concurrently.

  7.2  NOWAIT causes the statement to fail immediately with error 3572
       instead of waiting for a lock to be released.
*/
-- Worker A: claim the first unlocked account row
START TRANSACTION;
SELECT account_id, owner
FROM   accounts
FOR UPDATE SKIP LOCKED
LIMIT 1;
ROLLBACK;

-- NOWAIT example (returns ER_LOCK_NOWAIT if locked)
START TRANSACTION;
SELECT account_id
FROM   accounts
WHERE  owner = 'Bob'
FOR UPDATE NOWAIT;
ROLLBACK;

-------------------------------------------------
-- Region: 8. Isolation Level Summary
-------------------------------------------------
/*
  ╔═══════════════════╦══════════════╦══════════════════╦════════════════╗
  ║ Isolation Level   ║ Dirty Read   ║ Non-Repeatable   ║ Phantom Read   ║
  ╠═══════════════════╬══════════════╬══════════════════╬════════════════╣
  ║ READ UNCOMMITTED  ║ Possible     ║ Possible         ║ Possible       ║
  ║ READ COMMITTED    ║ Not possible ║ Possible         ║ Possible       ║
  ║ REPEATABLE READ   ║ Not possible ║ Not possible     ║ Mostly blocked ║
  ║ SERIALIZABLE      ║ Not possible ║ Not possible     ║ Not possible   ║
  ╚═══════════════════╩══════════════╩══════════════════╩════════════════╝

  InnoDB uses MVCC for READ COMMITTED and REPEATABLE READ so plain
  SELECTs never block writers (non-blocking reads).
*/
SELECT 'See comment above for the isolation level comparison table.' AS note;

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS isolation_demo;
DROP TABLE IF EXISTS accounts;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
