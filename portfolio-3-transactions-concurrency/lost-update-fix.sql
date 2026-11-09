-- FundWise lost-update fix (PostgreSQL)
-- Portfolio 3: Transactions and Concurrency, part 3 (the control)
-- SELECT ... FOR UPDATE locks the row. The second session waits.
-- Two sessions (Tab A, Tab B), run step by step.

-- Setup (either tab)
DROP TABLE IF EXISTS demo_wallet;
CREATE TABLE demo_wallet (
    wallet_id INT PRIMARY KEY,
    balance   NUMERIC(18,2) NOT NULL CHECK (balance >= 0)
);
INSERT INTO demo_wallet VALUES (1, 1000.00);

-- Step 1 (Tab A): read and lock the row
BEGIN;
SELECT balance FROM demo_wallet WHERE wallet_id = 1 FOR UPDATE;   -- shows 1000

-- Step 2 (Tab B): try to lock the same row; this blocks
BEGIN;
SELECT balance FROM demo_wallet WHERE wallet_id = 1 FOR UPDATE;   -- hangs until Tab A commits

-- Step 3 (Tab A): withdraw 200 and commit. Tab B wakes up.
UPDATE demo_wallet SET balance = balance - 200 WHERE wallet_id = 1;
COMMIT;

-- Step 4 (Tab B): Tab B now shows 800, not 1000. Withdraw 300.
UPDATE demo_wallet SET balance = balance - 300 WHERE wallet_id = 1;
COMMIT;

-- Step 5 (either tab): check the result
SELECT balance FROM demo_wallet WHERE wallet_id = 1;              -- shows 500, correct