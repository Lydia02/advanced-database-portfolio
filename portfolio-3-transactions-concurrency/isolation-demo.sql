-- FundWise isolation demo (PostgreSQL)
-- Portfolio 3: Transactions and Concurrency, part 4 (isolation levels)
-- Two sessions (Tab A, Tab B), run step by step.

-- Setup (either tab)
DROP TABLE IF EXISTS demo_wallet;
CREATE TABLE demo_wallet (
    wallet_id INT PRIMARY KEY,
    balance   NUMERIC(18,2) NOT NULL CHECK (balance >= 0)
);
INSERT INTO demo_wallet VALUES (1, 1000.00);

-- Part 1: READ COMMITTED (the default)

-- Step 1 (Tab A):
BEGIN;
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 1000

-- Step 2 (Tab B): withdraw 300 and commit
UPDATE demo_wallet SET balance = balance - 300 WHERE wallet_id = 1;

-- Step 3 (Tab A): read again inside the same transaction
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 700 (non-repeatable read)
ROLLBACK;

-- Part 2: REPEATABLE READ

-- Reset (either tab)
UPDATE demo_wallet SET balance = 1000 WHERE wallet_id = 1;

-- Step 4 (Tab A):
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 1000

-- Step 5 (Tab B): withdraw 300 and commit
UPDATE demo_wallet SET balance = balance - 300 WHERE wallet_id = 1;

-- Step 6 (Tab A): read again
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- still 1000 (same snapshot)

-- Step 7 (Tab A): try to withdraw 200
UPDATE demo_wallet SET balance = balance - 200 WHERE wallet_id = 1;
-- ERROR: could not serialize access due to concurrent update
ROLLBACK;