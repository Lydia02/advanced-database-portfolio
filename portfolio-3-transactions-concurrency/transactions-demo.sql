-- FundWise transactions demo (PostgreSQL)
-- Portfolio 3: Transactions and Concurrency, part 1 (atomicity)
-- Wallets used: 4500 (sender) and 777 (receiver)

DROP TABLE IF EXISTS txn_demo_log;
CREATE TABLE txn_demo_log (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    step   TEXT,
    detail TEXT
);

-- Atomic transfer: every statement inside succeeds or none do
CREATE OR REPLACE FUNCTION transfer_funds(
    p_from BIGINT, p_to BIGINT, p_amount NUMERIC, p_ref TEXT)
RETURNS BIGINT AS $$
DECLARE
    v_transfer_id BIGINT;
    v_from_bal    NUMERIC;
    v_to_bal      NUMERIC;
BEGIN
    INSERT INTO transfers (from_wallet_id, to_wallet_id, amount, status)
    VALUES (p_from, p_to, p_amount, 'pending')
    RETURNING transfer_id INTO v_transfer_id;

    -- the CHECK (balance >= 0) on wallets rejects an overdraft here
    UPDATE wallets SET balance = balance - p_amount
    WHERE wallet_id = p_from RETURNING balance INTO v_from_bal;

    UPDATE wallets SET balance = balance + p_amount
    WHERE wallet_id = p_to RETURNING balance INTO v_to_bal;

    INSERT INTO transactions (wallet_id, transfer_id, txn_type, amount, balance_after, reference)
    VALUES (p_from, v_transfer_id, 'transfer_out', p_amount, v_from_bal, p_ref || '-OUT'),
           (p_to,   v_transfer_id, 'transfer_in',  p_amount, v_to_bal,   p_ref || '-IN');

    UPDATE transfers SET status = 'completed' WHERE transfer_id = v_transfer_id;
    RETURN v_transfer_id;
END $$ LANGUAGE plpgsql;

-- 1. Balances before
INSERT INTO txn_demo_log (step, detail)
SELECT '1 before', format('wallet %s balance %s', wallet_id, balance)
FROM wallets WHERE wallet_id IN (4500, 777) ORDER BY wallet_id;

-- 2. COMMIT: transfer 1,000 from 4500 to 777
BEGIN;
SELECT transfer_funds(4500, 777, 1000, 'DEMO-' || extract(epoch FROM clock_timestamp())::bigint);
COMMIT;

INSERT INTO txn_demo_log (step, detail)
SELECT '2 after COMMIT', format('wallet %s balance %s', wallet_id, balance)
FROM wallets WHERE wallet_id IN (4500, 777) ORDER BY wallet_id;

-- 3. ROLLBACK: change a balance, then undo it
DO $$
DECLARE
    v_before NUMERIC;
    v_inside NUMERIC;
    v_after  NUMERIC;
BEGIN
    SELECT balance INTO v_before FROM wallets WHERE wallet_id = 4500;
    BEGIN
        UPDATE wallets SET balance = balance - 500
        WHERE wallet_id = 4500 RETURNING balance INTO v_inside;
        RAISE EXCEPTION 'forced rollback';
    EXCEPTION WHEN OTHERS THEN
        NULL;  -- the update above is undone here
    END;
    SELECT balance INTO v_after FROM wallets WHERE wallet_id = 4500;
    INSERT INTO txn_demo_log (step, detail)
    VALUES ('3 ROLLBACK',
            format('wallet 4500: before %s, inside transaction %s, after rollback %s',
                   v_before, v_inside, v_after));
END $$;

-- 4. Failed transfer: amount larger than the balance
DO $$
DECLARE
    v_msg TEXT;
BEGIN
    BEGIN
        PERFORM transfer_funds(777, 4500, 999999999, 'FAIL-DEMO');
    EXCEPTION WHEN OTHERS THEN
        v_msg := SQLERRM;
    END;
    INSERT INTO txn_demo_log (step, detail)
    VALUES ('4 failed transfer', 'rejected: ' || v_msg);
END $$;

INSERT INTO txn_demo_log (step, detail)
SELECT '4 after failed transfer', format('wallet %s balance %s', wallet_id, balance)
FROM wallets WHERE wallet_id IN (4500, 777) ORDER BY wallet_id;

INSERT INTO txn_demo_log (step, detail)
SELECT '4 leftover rows from failed transfer',
       format('ledger rows %s, transfer rows %s',
              (SELECT count(*) FROM transactions WHERE reference LIKE 'FAIL-DEMO%'),
              (SELECT count(*) FROM transfers WHERE amount = 999999999));

-- 5. Audit: stored balance still equals the ledger
INSERT INTO txn_demo_log (step, detail)
SELECT '5 audit', format('wallet %s stored %s ledger %s', w.wallet_id, w.balance,
       sum(CASE WHEN t.txn_type IN ('deposit', 'transfer_in') THEN t.amount ELSE -t.amount END))
FROM wallets w JOIN transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id IN (4500, 777)
GROUP BY w.wallet_id, w.balance ORDER BY w.wallet_id;

-- Results
SELECT step, detail FROM txn_demo_log ORDER BY id;