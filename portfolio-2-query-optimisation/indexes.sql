-- FundWise indexes (PostgreSQL)
-- Portfolio 2: Query Processing and Optimisation

-- Q1: filter on wallet, sorted by newest first
CREATE INDEX idx_transactions_wallet_created
    ON transactions (wallet_id, created_at DESC, txn_id DESC);

-- Q2: filter on sender
CREATE INDEX idx_transfers_from_wallet
    ON transfers (from_wallet_id);

-- Q3: filter on wallet, then a date range
CREATE INDEX idx_orders_wallet_created
    ON orders (wallet_id, created_at);

ANALYZE;