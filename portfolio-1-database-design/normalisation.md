# Portfolio 1: Normalisation

## Starting point: one flat table

    fundwise_flat(user_id, full_name, email, phone, kyc_status,
                  wallet_id, balance,
                  txn_id, txn_type, amount,
                  product_id, product_name, product_type, risk_level,
                  units, unit_price, price_date)

Problems with this design:

- **Update anomaly:** a user's email is repeated on every transaction row. Change it in one row and the data disagrees.
- **Insert anomaly:** a new product cannot be stored until someone trades it.
- **Delete anomaly:** deleting a user's last transaction deletes the user's details.

## 1NF: atomic values, a key on every table

- Every column holds one value. No lists such as "MMF, TBILL" in one cell.
- No repeating groups. Many holdings per user go in their own rows in `holdings`.
- Every table has a primary key (`BIGINT` identity).

## 2NF: no partial dependency on a composite key

- In the flat table the key is (`txn_id`, `product_id`). `product_name`, `product_type` and `risk_level` depend on `product_id` alone. That is a partial dependency.
- Fix: move them to `products`.
- `product_prices` is identified by (`product_id`, `price_date`). `unit_price` depends on both, so it passes. The pair is enforced with a UNIQUE constraint.
- `holdings` is identified by (`user_id`, `product_id`). `units` and `avg_cost` depend on both, so it passes. The pair is also UNIQUE.

## 3NF: no transitive dependency

A non-key column must depend on the key, the whole key, and nothing but the key.

- `kyc_status`, `email`, `phone` depend on `user_id`, not on a transaction. They stay in `users`.
- `balance` depends on `wallet_id`. It stays in `wallets`.
- `risk_level` depends on `product_id`, not on an order. It stays in `products`.
- `from_wallet_id` and `to_wallet_id` describe one event. They stay in `transfers`, not in every ledger row.

## Result per table

| Table | Primary key | Depends on | Normal form |
|---|---|---|---|
| users | user_id | full row | 3NF |
| wallets | wallet_id | full row | 3NF |
| transfers | transfer_id | full row | 3NF |
| transactions | txn_id | full row | 3NF |
| products | product_id | full row | 3NF |
| product_prices | price_id (unique: product_id, price_date) | full row | 3NF |
| orders | order_id | full row | 3NF |
| holdings | holding_id (unique: user_id, product_id) | full row | 3NF |

## Deliberate denormalisation

Four columns repeat or derive data on purpose.

| Column | Why it exists | How it is kept correct |
|---|---|---|
| wallets.balance | Derivable from the ledger. Stored so a balance read is one row, not a sum of every transaction | Updated in the same transaction as the ledger insert (Portfolio 3). An audit query compares it to the ledger |
| transactions.balance_after | Snapshot of the balance after each entry. Makes the audit trail checkable | Written with the ledger row, never edited |
| orders.unit_price | Price at the moment of the trade. Not redundant, because product_prices changes daily | Copied once at order time |
| holdings.units, avg_cost | Derivable from filled orders. Stored for fast portfolio reads | Updated in the same transaction as the order fill |

Trade-off: faster reads, at the cost of keeping copies in sync. Transactions (Portfolio 3) are what keep them in sync.