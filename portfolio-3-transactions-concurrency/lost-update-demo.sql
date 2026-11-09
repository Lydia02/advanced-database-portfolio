-- FundWise lost-update demo (PostgreSQL)
-- Portfolio 3: Transactions and Concurrency, part 2 (the problem)
-- Two sessions (Tab A, Tab B) both withdraw from the same wallet.

-- Setup (either tab)
DROP TABLE IF EXISTS demo_wallet;
CREATE TABLE demo_wallet (
    wallet_id INT PRIMARY KEY,
    balance   NUMERIC(18,2) NOT NULL CHECK (balance >= 0)
);
INSERT INTO demo_wallet VALUES (1, 1000.00);

-- Step 1 (Tab A): read the balance
BEGIN;
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 1000

-- Step 2 (Tab B): read the balance
BEGIN;
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 1000

-- Step 3 (Tab A): withdraw 200, using the balance it read
UPDATE demo_wallet SET balance = 1000 - 200 WHERE wallet_id = 1;
COMMIT;

-- Step 4 (Tab B): withdraw 300, using the balance it read earlier
UPDATE demo_wallet SET balance = 1000 - 300 WHERE wallet_id = 1;
COMMIT;

-- Step 5 (either tab): check the result
SELECT balance FROM demo_wallet WHERE wallet_id = 1;      -- shows 700, should be 500