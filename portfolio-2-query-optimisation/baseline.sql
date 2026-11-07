-- FundWise baseline execution plans (no indexes added yet)
-- Portfolio 2: Query Processing and Optimisation

-- Q1. Wallet statement
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, txn_type, amount, balance_after, created_at
FROM transactions
WHERE wallet_id = 4500
ORDER BY created_at DESC, txn_id DESC
LIMIT 20;

-- Q2. Transfers sent by one wallet
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, to_wallet_id, amount, status, created_at
FROM transfers
WHERE from_wallet_id = 777
ORDER BY created_at DESC;

-- Q3. Orders for one wallet in a date range
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, product_id, units, unit_price, created_at
FROM orders
WHERE wallet_id = 321
  AND created_at >= '2026-03-01'
  AND created_at <  '2026-07-01'
ORDER BY created_at;

-- Q5. Top 10 wallets by total deposits
EXPLAIN (ANALYZE, BUFFERS)
SELECT wallet_id, count(*) AS deposits, sum(amount) AS total_deposited
FROM transactions
WHERE txn_type = 'deposit'
GROUP BY wallet_id
ORDER BY total_deposited DESC
LIMIT 10;