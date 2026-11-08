// FundWise MongoDB queries (mongosh)
// Portfolio 4: NoSQL and Advanced Data Models

const d = db.getSiblingDB('fundwise_nosql');
const line = t => print('\n=== ' + t + ' ===');

// M1. Portfolio page: one lookup by _id
line('M1 portfolio for user 1234');
printjson(d.portfolios.findOne({ _id: 1234 }, { user: 1, wallet: 1, 'holdings.name': 1, 'holdings.units': 1 }));

// M2. Latest 5 unread events for a user (served by the user_id + created_at index)
line('M2 latest 5 unread events for user 1234');
printjson(d.activity_feed.find({ user_id: 1234, read: false }).sort({ created_at: -1 }).limit(5).toArray());

// M3. Users holding a given product (served by the holdings.product_id index)
line('M3 count of users holding product 7 (Equity Fund)');
print(d.portfolios.countDocuments({ 'holdings.product_id': 7 }));

// M4. Aggregation: total units and holders per product
line('M4 units and holders per product');
printjson(d.portfolios.aggregate([
  { $unwind: '$holdings' },
  { $group: { _id: '$holdings.name', holders: { $sum: 1 }, total_units: { $sum: '$holdings.units' } } },
  { $project: { holders: 1, total_units: { $round: ['$total_units', 2] } } },
  { $sort: { holders: -1 } }
]).toArray());

// M5. Aggregation: event counts by type
line('M5 events by type');
printjson(d.activity_feed.aggregate([
  { $group: { _id: '$type', events: { $sum: 1 } } },
  { $sort: { events: -1 } }
]).toArray());

// M6. Update: mark a user's unread events as read
line('M6 mark user 1234 events as read');
printjson(d.activity_feed.updateMany({ user_id: 1234, read: false }, { $set: { read: true } }));

// M7. Index evidence for M2
line('M7 explain for M2');
const ex = d.activity_feed.find({ user_id: 1234, read: false }).sort({ created_at: -1 }).limit(5).explain('executionStats').executionStats;
print('docs examined:   ' + ex.totalDocsExamined);
print('keys examined:   ' + ex.totalKeysExamined);
print('returned:        ' + ex.nReturned);
print('time (ms):       ' + ex.executionTimeMillis);

// M8. Same query with the index ignored
line('M8 same query without the index (collection scan)');
const ex2 = d.activity_feed.find({ user_id: 1234, read: false }).sort({ created_at: -1 }).limit(5).hint({ $natural: 1 }).explain('executionStats').executionStats;
print('docs examined:   ' + ex2.totalDocsExamined);
print('time (ms):       ' + ex2.executionTimeMillis);