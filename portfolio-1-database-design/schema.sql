-- FundWise schema (PostgreSQL)
-- Portfolio 1: Database Design and Modelling

DROP TABLE IF EXISTS holdings, orders, product_prices, products,
                     transactions, transfers, wallets, users CASCADE;

CREATE TABLE users (
    user_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   VARCHAR(200) NOT NULL,
    email       VARCHAR(320) NOT NULL UNIQUE,
    phone       VARCHAR(32)  NOT NULL UNIQUE,
    kyc_status  VARCHAR(32)  NOT NULL DEFAULT 'pending'
                CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
    created_at  TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE wallets (
    wallet_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL UNIQUE REFERENCES users(user_id),
    balance     NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    status      VARCHAR(32) NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'frozen', 'closed')),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE transfers (
    transfer_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_wallet_id  BIGINT NOT NULL REFERENCES wallets(wallet_id),
    to_wallet_id    BIGINT NOT NULL REFERENCES wallets(wallet_id),
    amount          NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    status          VARCHAR(32) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (from_wallet_id <> to_wallet_id)
);

CREATE TABLE transactions (
    txn_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_id      BIGINT NOT NULL REFERENCES wallets(wallet_id),
    transfer_id    BIGINT NULL REFERENCES transfers(transfer_id),
    txn_type       VARCHAR(32) NOT NULL
                   CHECK (txn_type IN ('deposit', 'withdrawal', 'transfer_out',
                                       'transfer_in', 'reversal', 'buy', 'sell')),
    amount         NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    balance_after  NUMERIC(18,2) NOT NULL CHECK (balance_after >= 0),
    reference      VARCHAR(128) NOT NULL UNIQUE,
    created_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE products (
    product_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(200) NOT NULL UNIQUE,
    product_type  VARCHAR(64) NOT NULL
                  CHECK (product_type IN ('money_market_fund', 'treasury_bill', 'mutual_fund')),
    risk_level    VARCHAR(32) NOT NULL
                  CHECK (risk_level IN ('low', 'medium', 'high')),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE product_prices (
    price_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT NOT NULL REFERENCES products(product_id),
    price_date  DATE NOT NULL,
    unit_price  NUMERIC(18,6) NOT NULL CHECK (unit_price > 0),
    UNIQUE (product_id, price_date)
);

CREATE TABLE orders (
    order_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_id   BIGINT NOT NULL REFERENCES wallets(wallet_id),
    product_id  BIGINT NOT NULL REFERENCES products(product_id),
    side        VARCHAR(16) NOT NULL CHECK (side IN ('buy', 'sell')),
    units       NUMERIC(18,6) NOT NULL CHECK (units > 0),
    unit_price  NUMERIC(18,6) NOT NULL CHECK (unit_price > 0),
    status      VARCHAR(32) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'filled', 'cancelled')),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE holdings (
    holding_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(user_id),
    product_id  BIGINT NOT NULL REFERENCES products(product_id),
    units       NUMERIC(18,6) NOT NULL CHECK (units >= 0),
    avg_cost    NUMERIC(18,6) NOT NULL CHECK (avg_cost >= 0),
    UNIQUE (user_id, product_id)
);
