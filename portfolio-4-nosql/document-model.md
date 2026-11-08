# Portfolio 4: NoSQL Document Model (MongoDB)

Database: `fundwise_nosql`. Same case study as Portfolios 1 to 3.

## What goes to MongoDB, and what stays in PostgreSQL

| Data | Where | Why |
|---|---|---|
| Wallets, ledger, transfers | PostgreSQL | Needs ACID and multi-row transactions (Portfolio 3) |
| Portfolio view per user | MongoDB | Read-heavy. One document replaces a 4-table join |
| Activity feed and notifications | MongoDB | Append-heavy. Payload shape differs per event type |

MongoDB holds a read model. PostgreSQL stays the source of truth for money.

## Collection 1: portfolios (one document per user)

```json
{
  "_id": 1234,
  "user": { "full_name": "User 1234", "email": "user1234@fundwise.test", "kyc_status": "verified" },
  "wallet": { "balance": 2802019.88, "status": "active" },
  "holdings": [
    { "product_id": 3, "name": "91-Day Treasury Bill", "type": "treasury_bill",
      "risk_level": "low", "units": 42.5, "avg_cost": 560.25 }
  ],
  "recent_transactions": [
    { "type": "deposit", "amount": 50000, "balance_after": 2802019.88, "at": "2026-06-30T10:15:00Z" }
  ],
  "updated_at": "2026-11-08T22:00:00Z"
}
```

Design choices:
- `_id` is the PostgreSQL `user_id`. The two systems join on it.
- Holdings are embedded. A portfolio is always read as a whole, and one user holds few products.
- `recent_transactions` keeps only the last 10. The full ledger stays in PostgreSQL. This keeps the document small.
- Product name and risk level are copied in so a portfolio page needs no second lookup.

## Collection 2: activity_feed (one document per event)

```json
{ "user_id": 1234, "type": "transfer_received",
  "payload": { "from_wallet": 777, "amount": 1000 },
  "read": false, "created_at": "2026-11-08T22:05:00Z" }
```

```json
{ "user_id": 1234, "type": "order_filled",
  "payload": { "product": "FundWise Growth Fund", "units": 10, "unit_price": 812.5 },
  "read": false, "created_at": "2026-11-08T22:07:00Z" }
```

Design choices:
- `payload` differs by `type`. A relational table would need nullable columns or one table per event type.
- Events are separate documents, not an array on the user. The feed grows without limit, and a single document is capped at 16 MB.
- Index: `{ user_id: 1, created_at: -1 }` serves "latest events for a user".

## Why a document store suits these two

- A portfolio read is one lookup by `_id`. In PostgreSQL it needs a join across users, wallets, holdings and products.
- New event types need no schema change.
- Both collections are append-and-read. Neither needs multi-row transactions.

## Where it does not suit

- Moving money. Two balances must change together or not at all. That stays in PostgreSQL.
- Copies can lag behind PostgreSQL, so the portfolio document is a view, not the truth.