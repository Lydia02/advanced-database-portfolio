// FundWise MongoDB seed (mongosh)
// Portfolio 4: NoSQL and Advanced Data Models
// Generates documents shaped like document-model.md

const d = db.getSiblingDB('fundwise_nosql');
d.portfolios.drop();
d.activity_feed.drop();

const products = [
  { product_id: 1, name: 'FundWise Money Market Fund',  type: 'money_market_fund', risk_level: 'low' },
  { product_id: 2, name: 'FundWise Stable Income Fund', type: 'money_market_fund', risk_level: 'low' },
  { product_id: 3, name: '91-Day Treasury Bill',        type: 'treasury_bill',     risk_level: 'low' },
  { product_id: 4, name: '182-Day Treasury Bill',       type: 'treasury_bill',     risk_level: 'low' },
  { product_id: 5, name: '364-Day Treasury Bill',       type: 'treasury_bill',     risk_level: 'medium' },
  { product_id: 6, name: 'FundWise Growth Fund',        type: 'mutual_fund',       risk_level: 'medium' },
  { product_id: 7, name: 'FundWise Equity Fund',        type: 'mutual_fund',       risk_level: 'high' },
  { product_id: 8, name: 'FundWise Balanced Fund',      type: 'mutual_fund',       risk_level: 'medium' }
];

const rnd = (a, b) => a + Math.random() * (b - a);
const money = n => Math.round(n * 100) / 100;
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const daysAgo = n => new Date(Date.now() - n * 86400000);

const txTypes = [
  { type: 'deposit',      sign:  1 },
  { type: 'withdrawal',   sign: -1 },
  { type: 'transfer_in',  sign:  1 },
  { type: 'transfer_out', sign: -1 }
];

// 1. portfolios: one document per user
let batch = [];
for (let id = 1; id <= 10000; id++) {
  const r = Math.random();
  const kyc = r < 0.85 ? 'verified' : r < 0.95 ? 'pending' : 'rejected';

  const nHold = Math.floor(Math.random() * 5);
  const held = products.slice().sort(() => Math.random() - 0.5).slice(0, nHold);
  const holdings = held.map(p => ({
    product_id: p.product_id,
    name: p.name,
    type: p.type,
    risk_level: p.risk_level,
    units: Math.round(rnd(1, 100) * 1e6) / 1e6,
    avg_cost: Math.round(rnd(100, 1500) * 1e6) / 1e6
  }));

  let bal = money(rnd(600000, 3000000));
  const walletBalance = bal;
  const recent = [];
  let age = 0;
  for (let i = 0; i < 10; i++) {
    const t = pick(txTypes);
    const amt = money(rnd(500, 50000));
    age += rnd(1, 12);
    recent.push({ type: t.type, amount: amt, balance_after: money(bal), at: daysAgo(age) });
    bal = money(bal - t.sign * amt);
  }

  batch.push({
    _id: id,
    user: { full_name: 'User ' + id, email: 'user' + id + '@fundwise.test', kyc_status: kyc },
    wallet: { balance: walletBalance, status: 'active' },
    holdings: holdings,
    recent_transactions: recent,
    updated_at: new Date()
  });

  if (batch.length === 1000) { d.portfolios.insertMany(batch); batch = []; }
}

// 2. activity_feed: one document per event
function payload(type) {
  switch (type) {
    case 'transfer_received':
      return { from_wallet: 1 + Math.floor(Math.random() * 10000), amount: money(rnd(100, 1000)) };
    case 'transfer_sent':
      return { to_wallet: 1 + Math.floor(Math.random() * 10000), amount: money(rnd(100, 1000)) };
    case 'order_filled': {
      const p = pick(products);
      return { product: p.name, units: money(rnd(1, 100)), unit_price: money(rnd(100, 1500)) };
    }
    case 'deposit_confirmed':
      return { amount: money(rnd(5000, 500000)), channel: pick(['card', 'bank_transfer', 'ussd']) };
    default:
      return { status: pick(['verified', 'pending', 'rejected']) };
  }
}

const feedTypes = ['transfer_received', 'transfer_sent', 'order_filled', 'deposit_confirmed', 'kyc_update'];
batch = [];
for (let i = 0; i < 100000; i++) {
  const type = pick(feedTypes);
  batch.push({
    user_id: 1 + Math.floor(Math.random() * 10000),
    type: type,
    payload: payload(type),
    read: Math.random() < 0.7,
    created_at: daysAgo(rnd(0, 300))
  });
  if (batch.length === 5000) { d.activity_feed.insertMany(batch); batch = []; }
}

// 3. indexes
d.activity_feed.createIndex({ user_id: 1, created_at: -1 });
d.portfolios.createIndex({ 'holdings.product_id': 1 });

// 4. verification output
print('--- sample portfolio (_id 1234) ---');
printjson(d.portfolios.findOne({ _id: 1234 }));
print('--- indexes ---');
print('portfolios:    ' + d.portfolios.getIndexes().map(i => i.name).join(', '));
print('activity_feed: ' + d.activity_feed.getIndexes().map(i => i.name).join(', '));
print('--- counts ---');
print('portfolios:    ' + d.portfolios.countDocuments());
print('activity_feed: ' + d.activity_feed.countDocuments());