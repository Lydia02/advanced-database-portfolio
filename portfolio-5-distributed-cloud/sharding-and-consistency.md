# Sharding, Consistency and Cloud Deployment

Scope: design discussion for FundWise. I built replication and failover for both databases. I did not build sharding.

## Why shard
Replication copies the same data to more servers. It helps availability and reads. It does not help when the data outgrows one server or one primary cannot take the writes. Sharding splits the data across servers.

My dataset is small (226,110 ledger rows). The ledger is the table that would outgrow one machine first.

## PostgreSQL: shard key for the ledger
Candidate: `wallet_id`, hashed.
- The wallet statement query (Q1) filters on one wallet, so it hits one shard.
- Rows spread evenly, so no shard becomes a hotspot.

Rejected keys:
- `created_at`: all new writes land on the newest shard (hotspot).
- `txn_id`: the statement query would have to ask every shard.

The cost: a transfer between two wallets on different shards touches two servers. It needs a distributed transaction (two-phase commit) or a saga with compensating steps. This is the hardest part of sharding a ledger. I would delay sharding until one primary cannot cope, and scale up first.

## MongoDB: shard keys
- `portfolios`: hashed `_id` (the user id). Every read is by user, so each read hits one shard.
- `activity_feed`: `user_id` plus `created_at`. "Latest events for a user" goes to one shard and stays ordered.

## Consistency
| Data | Choice | Why |
|---|---|---|
| Ledger and balances (PostgreSQL) | Consistency over availability | A wrong balance is worse than a short outage |
| Portfolio view and feed (MongoDB) | Availability over strict freshness | A slightly old feed is acceptable |

What I saw in my tests:
- PostgreSQL replication is asynchronous. A replica can lag. A commit not yet shipped can be lost in a failover. Balance reads stay on the primary.
- MongoDB with `w: "majority"` confirms a write after 2 of 3 nodes have it, so a failover cannot lose it. Reads from a secondary can be slightly stale.
- The MongoDB portfolio document is a read model. PostgreSQL stays the source of truth for money.

## Cloud deployment
- PostgreSQL: a managed service with a standby in a second availability zone and automatic failover. This replaces my manual `pg_promote()`.
- MongoDB: a managed replica set spread across zones, the same 3-node model I ran locally.
- Backups, patching and monitoring come with the managed service. The trade-off is cost and less control.

I did not deploy to a cloud provider. The Docker setup is the local equivalent.
