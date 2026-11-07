# Baseline results (no indexes)

Each query was run several times. The table shows the fastest run, because the first run is slowed by a cold cache.

| Query | Scan type | Rows removed | Fastest (ms) |
|---|---|---|---|
| Q1 wallet statement | Parallel Seq Scan on transactions | 113,046 per worker | 89.7 |
| Q2 transfers by wallet | Seq Scan on transfers | 39,998 | 12.9 |
| Q3 orders by wallet and date | Seq Scan on orders | 49,998 | 24.5 |
| Q5 top depositors | Seq Scan on transactions | 106,110 | 207 |

## Observations

- Q1, Q2 and Q3 read the whole table to return a few rows. There is no index on the filter column.
- Q1 uses two parallel workers. Each reads about half the table.
- Q5 reads every deposit row because it totals all of them. An index will not help much here.