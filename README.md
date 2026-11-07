# Case Study: FundWise

## Organisation
FundWise is a simulated investment and wallet platform. It is a realistic scenario, not a real company. No real customer data is used.

## Nature of the system
Users hold a naira wallet, move money in and out, and buy or sell investment products (money market funds, treasury bills, mutual funds). The system must keep balances exact and keep a full audit trail.

## Users of the database
- Investors: fund wallets, transfer money, trade, view portfolios
- Operations staff: review transactions, reverse failed transfers
- Compliance/audit: check balances against the ledger
- Admin: manage products and pricing

## Major data stored
- Users and KYC status
- Wallets and balances
- Transactions (deposits, withdrawals, transfers) as a ledger
- Investment products and daily prices
- Orders (buy/sell) and holdings
- Notifications and activity events

## Key operations
1. Register a user and create a wallet
2. Deposit and withdraw funds
3. Transfer funds between wallets
4. Reverse a failed transfer
5. Place a buy or sell order and update holdings
6. Audit a wallet balance against its ledger
7. Retrieve a portfolio and its transaction history

## How each portfolio uses it
| Portfolio | Use in FundWise |
|---|---|
| 1 Design | Relational schema for users, wallets, ledger, orders |
| 2 Queries | Statements, portfolio valuation, top spenders, with indexes |
| 3 Transactions | Atomic transfer, rollback on failure, concurrent debit |
| 4 NoSQL | Portfolio and activity-feed documents in MongoDB |
| 5 Distributed | Postgres replica, Mongo replica set, sharding discussion |
