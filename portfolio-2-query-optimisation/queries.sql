-- FundWise queries (PostgreSQL)
-- Portfolio 2: Query Processing and Optimisation
-- Baseline: run before adding any indexes.

-- Q1. Wallet statement: last 20 ledger entries for one wallet
SELECT txn_id, txn_type, amount, balance_after, created_at
FROM transactions
WHERE wallet_id = 4500
ORDER BY created_at DESC, txn_id DESC
LIMIT 20;

-- Q2. Transfers sent by one wallet
SELECT transfer_id, to_wallet_id, amount, status, created_at
FROM transfers
WHERE from_wallet_id = 777
ORDER BY created_at DESC;

-- Q3. Orders for one wallet in a date range
SELECT order_id, product_id, units, unit_price, created_at
FROM orders
WHERE wallet_id = 321
  AND created_at >= '2026-03-01'
  AND created_at <  '2026-07-01'
ORDER BY created_at;

-- Q4. Portfolio valuation for one user at the latest price
SELECT p.name, h.units, pp.unit_price,
       round(h.units * pp.unit_price, 2) AS value
FROM holdings h
JOIN products p ON p.product_id = h.product_id
JOIN LATERAL (
    SELECT unit_price
    FROM product_prices x
    WHERE x.product_id = h.product_id
    ORDER BY price_date DESC
    LIMIT 1
) pp ON true
WHERE h.user_id = 1234;

-- Q5. Top 10 wallets by total deposits
SELECT wallet_id, count(*) AS deposits, sum(amount) AS total_deposited
FROM transactions
WHERE txn_type = 'deposit'
GROUP BY wallet_id
ORDER BY total_deposited DESC
LIMIT 10;

-- Q6. Monthly transfer volume by status
SELECT date_trunc('month', created_at) AS month,
       status,
       count(*) AS transfers,
       sum(amount) AS total_amount
FROM transfers
GROUP BY 1, 2
ORDER BY 1, 2;

-- Q7. Audit: stored balance against ledger total for one wallet
SELECT w.wallet_id,
       w.balance AS stored_balance,
       sum(CASE WHEN t.txn_type IN ('deposit', 'transfer_in')
                THEN t.amount ELSE -t.amount END) AS ledger_total
FROM wallets w
JOIN transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id = 4500
GROUP BY w.wallet_id, w.balance;