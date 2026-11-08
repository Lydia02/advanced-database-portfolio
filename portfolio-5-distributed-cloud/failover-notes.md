# PostgreSQL Failover Notes

## Setup
- Primary on port 5433, one streaming replica on port 5434. Both run in Docker.
- The replica was built with `pg_basebackup`. Replication is asynchronous.
- I loaded the FundWise schema and seed data into the primary. The replica had all 10,000 users.
- The replica refused writes with a read-only error.

## What I did
1. Inserted "Replication Test Fund" on the primary. It showed up on the replica as product 9.
2. Stopped the primary container to simulate a crash.
3. Checked the replica: `pg_is_in_recovery()` returned `t`. It was still read-only.
4. Ran `pg_promote()` on the replica. It returned `t`.
5. Checked again: `pg_is_in_recovery()` returned `f`. The replica was now a primary.
6. Inserted "Post-Failover Fund" on it. The insert worked. The products table had 10 rows.

## What could have been lost
Replication is asynchronous. The primary confirms a commit before the replica has the data. If the primary dies in that gap, those commits are lost.

In this test nothing was lost. I confirmed product 9 on the replica before I stopped the primary.

For a ledger this matters. A confirmed transfer that vanishes in a failover is a serious fault. Synchronous replication closes the gap. The cost is slower writes, because each commit waits for the replica.

## What was manual
I ran the promotion myself. In production, a tool such as Patroni watches the primary, promotes the replica, and moves traffic to it.

## Why the old primary stays down
If it came back, two servers would both