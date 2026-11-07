# Portfolio 2: Performance Analysis

Dataset: 10,000 users, 226,110 ledger rows, 40,000 transfers, 50,000 orders.
Method: each query ran 5 times before and 5 times after the indexes. The table shows the fastest run.

| Query | Before | After | Faster |
|---|---|---|---|
| Q1 wallet statement | Parallel Seq Scan, 150 ms | Index Scan, 0.031 ms | 4,840x |
| Q2 transfers by wallet | Seq Scan, 5.1 ms | Bitmap Heap Scan, 0.036 ms | 141x |
| Q3 orders by wallet and date | Seq Scan, 37 ms | Bitmap Heap Scan, 0.038 ms | 980x |
| Q5 top depositors | Seq Scan, 195 ms | Seq Scan, 123 ms | 1.6x |

## Indexes added

- `idx_transactions_wallet_created` on transactions (wallet_id, created_at DESC, txn_id DESC)
- `idx_transfers_from_wallet` on transfers (from_wallet_id)
- `idx_orders_wallet_created` on orders (wallet_id, created_at)

## What happened

- Q1: the index puts one wallet's rows together, already sorted newest first. Postgres reads about 20 rows and the Sort step disappears.
- Q2: the index finds the 2 matching rows. Before, Postgres read all 40,000.
- Q3: wallet_id comes first because it is an equality filter. created_at comes second so the date range is read in order.
- Q5: no index was added. It totals about half the ledger, so there is no small set of rows to jump to. The gain from 195 ms to 123 ms is cache warm-up, not an index.

## Trade-offs

- Every index costs disk space.
- Every insert and update on those tables must also update the indexes, so writes get slower.
- A ledger takes many writes, so indexes were added only to the columns that real queries filter on.

## Reading the numbers

- Absolute times are small because the dataset is small. The ratio matters more. A scan grows with the table. An index lookup barely does.
- Timings vary between runs. Cold-cache first runs were up to 10x slower than later ones, which is why the table uses the fastest of 5.