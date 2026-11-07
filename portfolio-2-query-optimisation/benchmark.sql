-- FundWise benchmark (PostgreSQL)
-- Portfolio 2: runs Q1, Q2, Q3, Q5 before and after indexes.
-- Each query runs 5 times. The fastest time is kept.

DROP TABLE IF EXISTS bench_results;
CREATE TABLE bench_results (
    phase   text,
    label   text,
    run     int,
    scan    text,
    exec_ms numeric
);

CREATE OR REPLACE FUNCTION bench(p_phase text, p_label text, p_sql text, p_runs int DEFAULT 5)
RETURNS void AS $$
DECLARE
    r    record;
    i    int;
    scan text;
    t    numeric;
BEGIN
    FOR i IN 1..p_runs LOOP
        scan := NULL;
        t := NULL;
        FOR r IN EXECUTE 'EXPLAIN (ANALYZE) ' || p_sql LOOP
            IF r."QUERY PLAN" LIKE 'Execution Time:%' THEN
                t := substring(r."QUERY PLAN" from 'Execution Time: ([0-9.]+)')::numeric;
            END IF;
            IF scan IS NULL THEN
                scan := substring(r."QUERY PLAN" from
                    '(?:Parallel Seq Scan|Seq Scan|Index Only Scan|Index Scan|Bitmap Heap Scan)(?: using \S+)?');
            END IF;
        END LOOP;
        INSERT INTO bench_results VALUES (p_phase, p_label, i, scan, t);
    END LOOP;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bench_all(p_phase text)
RETURNS void AS $$
BEGIN
    PERFORM bench(p_phase, 'Q1 wallet statement', $q$
        SELECT txn_id, txn_type, amount, balance_after, created_at
        FROM transactions
        WHERE wallet_id = 4500
        ORDER BY created_at DESC, txn_id DESC
        LIMIT 20 $q$);

    PERFORM bench(p_phase, 'Q2 transfers by wallet', $q$
        SELECT transfer_id, to_wallet_id, amount, status, created_at
        FROM transfers
        WHERE from_wallet_id = 777
        ORDER BY created_at DESC $q$);

    PERFORM bench(p_phase, 'Q3 orders by wallet and date', $q$
        SELECT order_id, product_id, units, unit_price, created_at
        FROM orders
        WHERE wallet_id = 321
          AND created_at >= '2026-03-01'
          AND created_at <  '2026-07-01'
        ORDER BY created_at $q$);

    PERFORM bench(p_phase, 'Q5 top depositors', $q$
        SELECT wallet_id, count(*) AS deposits, sum(amount) AS total_deposited
        FROM transactions
        WHERE txn_type = 'deposit'
        GROUP BY wallet_id
        ORDER BY total_deposited DESC
        LIMIT 10 $q$);
END $$ LANGUAGE plpgsql;

-- BEFORE: no indexes
DROP INDEX IF EXISTS idx_transactions_wallet_created;
DROP INDEX IF EXISTS idx_transfers_from_wallet;
DROP INDEX IF EXISTS idx_orders_wallet_created;
ANALYZE;
SELECT bench_all('before');

-- AFTER: indexes added
CREATE INDEX idx_transactions_wallet_created
    ON transactions (wallet_id, created_at DESC, txn_id DESC);
CREATE INDEX idx_transfers_from_wallet
    ON transfers (from_wallet_id);
CREATE INDEX idx_orders_wallet_created
    ON orders (wallet_id, created_at);
ANALYZE;
SELECT bench_all('after');

-- RESULT TABLE (screenshot this)
SELECT label,
       max(scan) FILTER (WHERE phase = 'before')                      AS scan_before,
       round(min(exec_ms) FILTER (WHERE phase = 'before'), 3)         AS ms_before,
       max(scan) FILTER (WHERE phase = 'after')                       AS scan_after,
       round(min(exec_ms) FILTER (WHERE phase = 'after'), 3)          AS ms_after,
       round(min(exec_ms) FILTER (WHERE phase = 'before')
             / NULLIF(min(exec_ms) FILTER (WHERE phase = 'after'), 0), 1) AS times_faster
FROM bench_results
GROUP BY label
ORDER BY label;