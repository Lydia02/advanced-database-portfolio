-- FundWise seed data (PostgreSQL)
-- Portfolio 2: Query Processing and Optimisation
-- Run schema.sql first. This script wipes all tables and reloads them.

TRUNCATE holdings, orders, product_prices, products,
         transactions, transfers, wallets, users
         RESTART IDENTITY CASCADE;

-- 1. Users: 10,000
INSERT INTO users (full_name, email, phone, kyc_status, created_at)
SELECT 'User ' || n,
       'user' || n || '@fundwise.test',
       '+234800' || lpad(n::text, 7, '0'),
       CASE WHEN r < 0.85 THEN 'verified'
            WHEN r < 0.95 THEN 'pending'
            ELSE 'rejected' END,
       timestamp '2025-01-01' + random() * interval '300 days'
FROM (SELECT n, random() AS r FROM generate_series(1, 10000) n) s;

-- 2. Wallets: one per user, balance set after the ledger is built
INSERT INTO wallets (user_id, balance, status, created_at)
SELECT user_id, 0, 'active', created_at
FROM users
ORDER BY user_id;

-- 3. Products: 8
INSERT INTO products (name, product_type, risk_level) VALUES
 ('FundWise Money Market Fund',  'money_market_fund', 'low'),
 ('FundWise Stable Income Fund', 'money_market_fund', 'low'),
 ('91-Day Treasury Bill',        'treasury_bill',     'low'),
 ('182-Day Treasury Bill',       'treasury_bill',     'low'),
 ('364-Day Treasury Bill',       'treasury_bill',     'medium'),
 ('FundWise Growth Fund',        'mutual_fund',       'medium'),
 ('FundWise Equity Fund',        'mutual_fund',       'high'),
 ('FundWise Balanced Fund',      'mutual_fund',       'medium');

-- 4. Daily prices: 8 products x 365 days
INSERT INTO product_prices (product_id, price_date, unit_price)
SELECT p.product_id,
       date '2026-01-01' + d,
       round(((p.product_id * 150 + 100) * (1 + (random() - 0.5) * 0.02))::numeric, 6)FROM products p, generate_series(0, 364) d;

-- 5. Transfers: 40,000 (about 5% failed)
INSERT INTO transfers (from_wallet_id, to_wallet_id, amount, status, created_at)
SELECT f,
       ((f + floor(random() * 9999)::int) % 10000) + 1,
       round((100 + random() * 900)::numeric, 2),
       CASE WHEN random() < 0.95 THEN 'completed' ELSE 'failed' END,
       timestamp '2026-07-01' + random() * interval '120 days'
FROM (SELECT 1 + floor(random() * 10000)::int AS f
      FROM generate_series(1, 40000)) s;

-- 6. Ledger staging (signed amounts)
DROP TABLE IF EXISTS ledger_stage;
CREATE TEMP TABLE ledger_stage (
    seq           BIGINT GENERATED ALWAYS AS IDENTITY,
    wallet_id     BIGINT,
    transfer_id   BIGINT,
    txn_type      VARCHAR(32),
    signed_amount NUMERIC(18,2),
    created_at    TIMESTAMP,
    reference     VARCHAR(128)
);

-- 6a. Deposits: 12 per wallet, Jan to Jun
INSERT INTO ledger_stage (wallet_id, transfer_id, txn_type, signed_amount, created_at, reference)
SELECT w.wallet_id, NULL, 'deposit',
       round((5000 + random() * 495000)::numeric, 2),
       timestamp '2026-01-01' + random() * interval '180 days',
       'DEP-' || w.wallet_id || '-' || g
FROM wallets w, generate_series(1, 12) g;

-- 6b. Withdrawals: 3 per wallet, Jul to Oct
INSERT INTO ledger_stage (wallet_id, transfer_id, txn_type, signed_amount, created_at, reference)
SELECT w.wallet_id, NULL, 'withdrawal',
       -round((500 + random() * 9500)::numeric, 2),
       timestamp '2026-07-01' + random() * interval '120 days',
       'WDR-' || w.wallet_id || '-' || g
FROM wallets w, generate_series(1, 3) g;

-- 6c. Completed transfers: one debit row, one credit row
INSERT INTO ledger_stage (wallet_id, transfer_id, txn_type, signed_amount, created_at, reference)
SELECT from_wallet_id, transfer_id, 'transfer_out', -amount, created_at,
       'TRF-OUT-' || transfer_id
FROM transfers WHERE status = 'completed';

INSERT INTO ledger_stage (wallet_id, transfer_id, txn_type, signed_amount, created_at, reference)
SELECT to_wallet_id, transfer_id, 'transfer_in', amount, created_at,
       'TRF-IN-' || transfer_id
FROM transfers WHERE status = 'completed';

-- 7. Ledger with running balance_after
INSERT INTO transactions (wallet_id, transfer_id, txn_type, amount, balance_after, reference, created_at)
SELECT wallet_id, transfer_id, txn_type, abs(signed_amount),
       SUM(signed_amount) OVER (PARTITION BY wallet_id ORDER BY created_at, seq),
       reference, created_at
FROM ledger_stage
ORDER BY created_at, seq;

-- 8. Wallet balance = sum of its ledger
UPDATE wallets w
SET balance = s.total
FROM (SELECT wallet_id, SUM(signed_amount) AS total
      FROM ledger_stage GROUP BY wallet_id) s
WHERE s.wallet_id = w.wallet_id;

-- 9. Orders: 50,000 filled buys
INSERT INTO orders (wallet_id, product_id, side, units, unit_price, status, created_at)
SELECT 1 + floor(random() * 10000)::int,
       1 + floor(random() * 8)::int,
       'buy',
       round((1 + random() * 99)::numeric, 6),
       round((100 + random() * 1400)::numeric, 6),
       'filled',
       timestamp '2026-01-01' + random() * interval '300 days'
FROM generate_series(1, 50000);

-- 10. Holdings from orders (wallet n belongs to user n)
INSERT INTO holdings (user_id, product_id, units, avg_cost)
SELECT wallet_id, product_id, SUM(units),
       round(SUM(units * unit_price) / SUM(units), 6)
FROM orders
GROUP BY wallet_id, product_id;

ANALYZE;

-- Row counts
SELECT 'users' AS tbl, count(*) FROM users
UNION ALL SELECT 'wallets', count(*) FROM wallets
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'product_prices', count(*) FROM product_prices
UNION ALL SELECT 'transfers', count(*) FROM transfers
UNION ALL SELECT 'transactions', count(*) FROM transactions
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'holdings', count(*) FROM holdings;