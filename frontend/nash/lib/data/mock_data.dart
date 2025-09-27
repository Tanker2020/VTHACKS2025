// Centralized mock "databases" for local development

List<Map<String, dynamic>> mockUsers = [
  {
    'id': 'user-1000',
    'username': 'alice',
    'display_name': 'Alice M',
    'bio': 'Builder of small predictions and careful lender.',
    'followers': 120,
    'following': 34,
    'nashScore': 84,
    'balance': 1000.0,
  },
  {
    'id': 'user-1001',
    'username': 'bob',
    'display_name': 'Bob J',
    'bio': 'Data scientist and avid contributor.',
    'followers': 54,
    'following': 12,
    'nashScore': 66,
    'balance': 850.0,
  },
  {
    'id': 'user-1002',
    'username': 'carla',
    'display_name': 'Carla P',
    'bio': 'Community organizer and borrower.',
    'followers': 240,
    'following': 88,
    'nashScore': 92,
    'balance': 420.0,
  },
  {
    'id': 'user-1003',
    'username': 'dan',
    'display_name': 'Dan K',
    'bio': 'Occasional predictor and lender.',
    'followers': 18,
    'following': 6,
    'nashScore': 48,
    'balance': 230.0,
  },
  {
    'id': 'user-1004',
    'username': 'eve',
    'display_name': 'Eve R',
    'bio': 'Startup founder, needs bridge loans.',
    'followers': 310,
    'following': 110,
    'nashScore': 95,
    'balance': 1500.0,
  },
  {
    'id': 'user-1005',
    'username': 'frank',
    'display_name': 'Frank L',
    'bio': 'Hobbyist predictor.',
    'followers': 8,
    'following': 2,
    'nashScore': 40,
    'balance': 75.0,
  },
];

// Current mock signed-in user id for demo purposes
String currentMockUserId = 'user-1000';

// Positions store
List<Map<String, dynamic>> mockPositions = [];

int _nextPositionId() {
  var maxId = 0;
  for (final p in mockPositions) {
    final v = p['id'];
    if (v is int && v > maxId) maxId = v;
  }
  return maxId + 1;
}

Map<String, dynamic>? findUserRefById(String id) {
  final idx = mockUsers.indexWhere((u) => u['id'] == id);
  if (idx == -1) return null;
  return mockUsers[idx];
}

bool adjustUserBalance(String userId, double delta) {
  final user = findUserRefById(userId);
  if (user == null) return false;
  final bal = (user['balance'] is num) ? (user['balance'] as num).toDouble() : 0.0;
  final newBal = bal + delta;
  if (newBal < 0) return false;
  user['balance'] = newBal;
  return true;
}

Map<String, dynamic>? createPosition(String userId, int assetId, String side, double qty, double entryPrice) {
  // cost to open = qty * entryPrice
  final cost = qty * entryPrice;
  final ok = adjustUserBalance(userId, -cost);
  if (!ok) return null;
  final pos = {
    'id': _nextPositionId(),
    'userId': userId,
    'assetId': assetId,
    'side': side,
    'qty': qty,
    'entryPrice': entryPrice,
    'openAt': DateTime.now().toIso8601String(),
    'status': 'open',
  };
  mockPositions.add(pos);
  // update asset long/short counters
  final aidx = mockAssets.indexWhere((a) => a['id'] == assetId);
  if (aidx != -1) {
    final asset = Map<String, dynamic>.from(mockAssets[aidx]);
    final currLong = (asset['long'] is num) ? (asset['long'] as num).toDouble() : 0.0;
    final currShort = (asset['short'] is num) ? (asset['short'] as num).toDouble() : 0.0;
    if ((side.toLowerCase()) == 'long') {
      asset['long'] = currLong + qty;
    } else {
      asset['short'] = currShort + qty;
    }
    asset['price'] = computePriceString(asset);
    mockAssets[aidx] = asset;
  }
  return pos;
}

Map<String, dynamic>? findPositionById(int id) {
  final idx = mockPositions.indexWhere((p) => p['id'] == id);
  if (idx == -1) return null;
  return mockPositions[idx];
}

bool closePosition(int id) {
  final idx = mockPositions.indexWhere((p) => p['id'] == id);
  if (idx == -1) return false;
  final pos = Map<String, dynamic>.from(mockPositions[idx]);
  if (pos['status'] != 'open') return false;
  final assetId = pos['assetId'] as int;
  final assetIdx = mockAssets.indexWhere((a) => a['id'] == assetId);
  if (assetIdx == -1) return false;
  final asset = mockAssets[assetIdx];
  final currentPrice = (asset['price'] is String) ? double.tryParse(asset['price']) ?? computePriceFromSides(asset) : (asset['price'] as num).toDouble();
  final qty = (pos['qty'] is num) ? (pos['qty'] as num).toDouble() : 0.0;
  // credit user with qty * currentPrice (sell proceeds)
  final userId = pos['userId'] as String;
  adjustUserBalance(userId, qty * currentPrice);
  // decrement asset counters for this closed position
  final a = Map<String, dynamic>.from(mockAssets[assetIdx]);
  final currLong = (a['long'] is num) ? (a['long'] as num).toDouble() : 0.0;
  final currShort = (a['short'] is num) ? (a['short'] as num).toDouble() : 0.0;
  if ((pos['side'] as String).toLowerCase() == 'long') {
    a['long'] = (currLong - qty) < 0 ? 0 : (currLong - qty);
  } else {
    a['short'] = (currShort - qty) < 0 ? 0 : (currShort - qty);
  }
  a['price'] = computePriceString(a);
  mockAssets[assetIdx] = a;
  // mark closed and record close info
  mockPositions[idx]['status'] = 'closed';
  mockPositions[idx]['closedAt'] = DateTime.now().toIso8601String();
  mockPositions[idx]['closePrice'] = currentPrice;
  return true;
}

List<Map<String, dynamic>> getUserPositions(String userId) => mockPositions.where((p) => p['userId'] == userId).toList();

List<Map<String, dynamic>> mockAssets = [
  // Loans
  {
    'id': 1,
    'type': 'loan',
    'title': 'Loan Request — Community Garden',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'Normal',
    'loan_total': 500.0,
    'loan_raised': 150.0,
    'loan_rate': 5.0,
    'loan_duration_months': 6,
    'borrower_id': 'user-1000',
  },
  {
    'id': 2,
    'type': 'loan',
    'title': 'Loan Request — App Hosting',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'High',
    'loan_total': 800.0,
    'loan_raised': 320.0,
    'loan_rate': 7.5,
    'loan_duration_months': 12,
    'borrower_id': 'user-1004',
  },
  {
    'id': 3,
    'type': 'loan',
    'title': 'Loan Request — Market Research',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'Low',
    'loan_total': 350.0,
    'loan_raised': 50.0,
    'loan_rate': 6.0,
    'loan_duration_months': 9,
    'borrower_id': 'user-1002',
  },
  // Predictions
  {
    'id': 4,
    'type': 'prediction',
    'title': 'Prediction — BTC Price Surge',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Predictions',
    'urgency': 'Normal',
    'borrower_id': null,
    // price history: list of {t: ISO8601, p: price}
    'price_history': [
      {'t': '2025-09-20T00:00:00Z', 'p': 6.5},
      {'t': '2025-09-21T00:00:00Z', 'p': 7.2},
      {'t': '2025-09-22T00:00:00Z', 'p': 8.1},
      {'t': '2025-09-23T00:00:00Z', 'p': 9.4},
      {'t': '2025-09-24T00:00:00Z', 'p': 9.0},
      {'t': '2025-09-25T00:00:00Z', 'p': 10.2},
      {'t': '2025-09-26T00:00:00Z', 'p': 9.99},
    ],
  },
  {
    'id': 5,
    'type': 'prediction',
    'title': 'Prediction — Election Outcome',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Predictions',
    'urgency': 'Normal',
    'borrower_id': null,
    'price_history': [
      {'t': '2025-09-20T00:00:00Z', 'p': 11.0},
      {'t': '2025-09-21T00:00:00Z', 'p': 11.5},
      {'t': '2025-09-22T00:00:00Z', 'p': 12.1},
      {'t': '2025-09-23T00:00:00Z', 'p': 12.4},
      {'t': '2025-09-24T00:00:00Z', 'p': 12.0},
      {'t': '2025-09-25T00:00:00Z', 'p': 12.3},
      {'t': '2025-09-26T00:00:00Z', 'p': 12.0},
    ],
  },
  // Mixed
  {
    'id': 6,
    'type': 'loan',
    'title': 'Loan Request — Seed Funding',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'High',
    'loan_total': 1200.0,
    'loan_raised': 600.0,
    'loan_rate': 8.0,
    'loan_duration_months': 18,
    'borrower_id': 'user-1001',
  },
  {
    'id': 7,
    'type': 'prediction',
    'title': 'Prediction — Sports Upset',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Other',
    'urgency': 'Low',
    'borrower_id': null,
    'price_history': [
      {'t': '2025-09-20T00:00:00Z', 'p': 3.2},
      {'t': '2025-09-21T00:00:00Z', 'p': 3.5},
      {'t': '2025-09-22T00:00:00Z', 'p': 4.0},
      {'t': '2025-09-23T00:00:00Z', 'p': 4.3},
      {'t': '2025-09-24T00:00:00Z', 'p': 4.8},
      {'t': '2025-09-25T00:00:00Z', 'p': 4.6},
      {'t': '2025-09-26T00:00:00Z', 'p': 4.5},
    ],
  },
  {
    'id': 8,
    'type': 'loan',
    'title': 'Loan Request — Equipment',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'Normal',
    'loan_total': 950.0,
    'loan_raised': 200.0,
    'loan_rate': 6.5,
    'loan_duration_months': 10,
    'borrower_id': 'user-1003',
  },
  {
    'id': 9,
    'type': 'prediction',
    'title': 'Prediction — Tech Adoption',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Predictions',
    'urgency': 'Normal',
    'borrower_id': null,
    'price_history': [
      {'t': '2025-09-20T00:00:00Z', 'p': 5.5},
      {'t': '2025-09-21T00:00:00Z', 'p': 5.9},
      {'t': '2025-09-22T00:00:00Z', 'p': 6.8},
      {'t': '2025-09-23T00:00:00Z', 'p': 7.0},
      {'t': '2025-09-24T00:00:00Z', 'p': 7.3},
      {'t': '2025-09-25T00:00:00Z', 'p': 7.1},
      {'t': '2025-09-26T00:00:00Z', 'p': 7.25},
    ],
  },
  {
    'id': 10,
    'type': 'loan',
    'title': 'Loan Request — Expansion',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'High',
    'loan_total': 2200.0,
    'loan_raised': 1800.0,
    'loan_rate': 9.0,
    'loan_duration_months': 24,
    'borrower_id': 'user-1004',
  },
  {
    'id': 11,
    'type': 'prediction',
    'title': 'Prediction — Weather Event',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Other',
    'urgency': 'Low',
    'borrower_id': null,
    'price_history': [
      {'t': '2025-09-20T00:00:00Z', 'p': 2.5},
      {'t': '2025-09-21T00:00:00Z', 'p': 2.8},
      {'t': '2025-09-22T00:00:00Z', 'p': 3.1},
      {'t': '2025-09-23T00:00:00Z', 'p': 3.6},
      {'t': '2025-09-24T00:00:00Z', 'p': 3.9},
      {'t': '2025-09-25T00:00:00Z', 'p': 3.95},
      {'t': '2025-09-26T00:00:00Z', 'p': 3.99},
    ],
  },
  {
    'id': 12,
    'type': 'loan',
    'title': 'Loan Request — Community Event',
    'price': '0.50',
    'long': 1,
    'short': 1,
    'category': 'Open Loans',
    'urgency': 'Normal',
    'loan_total': 400.0,
    'loan_raised': 100.0,
    'loan_rate': 4.5,
    'loan_duration_months': 6,
    'borrower_id': 'user-1000',
  },
];

/// Compute a price double from long/short counts.
double computePriceFromSides(Map<String, dynamic> asset) {
  final l = (asset['long'] is num) ? (asset['long'] as num).toDouble() : 0.0;
  final s = (asset['short'] is num) ? (asset['short'] as num).toDouble() : 0.0;
  final denom = l + s;
  if (denom <= 0) return 0.5;
  return l / denom;
}

String computePriceString(Map<String, dynamic> asset) {
  final p = computePriceFromSides(asset);
  return p.toStringAsFixed(2);
}

Map<String, dynamic>? findUserById(String id) {
  // id is non-nullable; return null if no user found
  final found = mockUsers.firstWhere((u) => u['id'] == id, orElse: () => {});
  if (found.isEmpty) return null;
  return found;
}

/// Append an asset to the in-memory mockAssets list and return the added map.
Map<String, dynamic> addAsset(Map<String, dynamic> asset) {
  // determine next integer id
  var maxId = 0;
  for (final a in mockAssets) {
    final v = a['id'];
    if (v is int && v > maxId) maxId = v;
  }
  final nextId = maxId + 1;
  final Map<String, dynamic> toAdd = Map<String, dynamic>.from(asset);
  toAdd['id'] = nextId;
  // ensure long/short counters exist
  if (!toAdd.containsKey('long')) toAdd['long'] = 1;
  if (!toAdd.containsKey('short')) toAdd['short'] = 1;
  // compute price from long/short
  toAdd['price'] = computePriceString(toAdd);
  mockAssets.add(toAdd);
  return toAdd;
}

/// Update an existing asset by id with provided changes. Returns updated asset or null.
Map<String, dynamic>? updateAsset(int id, Map<String, dynamic> changes) {
  final idx = mockAssets.indexWhere((a) => a['id'] == id);
  if (idx == -1) return null;
  final merged = Map<String, dynamic>.from(mockAssets[idx])..addAll(changes);
  // ensure long/short default if missing
  if (!merged.containsKey('long')) merged['long'] = mockAssets[idx]['long'] ?? 1;
  if (!merged.containsKey('short')) merged['short'] = mockAssets[idx]['short'] ?? 1;
  // recompute price from sides
  merged['price'] = computePriceString(merged);
  mockAssets[idx] = merged;
  return merged;
}

/// Fulfill a loan completely and convert it to a prediction asset.
Map<String, dynamic>? fulfillLoan(int id) {
  final idx = mockAssets.indexWhere((a) => a['id'] == id);
  if (idx == -1) return null;
  final asset = Map<String, dynamic>.from(mockAssets[idx]);
  final loanTotal = asset['loan_total'];
  // convert to prediction
  asset['type'] = 'prediction';
  asset['category'] = 'Predictions';
  // set price of the new prediction to the loan total (if available)
  if (loanTotal != null) {
    // Initialize long/short from loanTotal if desired, otherwise set defaults and compute
    asset['long'] = asset['long'] ?? 1;
    asset['short'] = asset['short'] ?? 1;
    asset['price'] = computePriceString(asset);
  }
  // remove loan-specific fields
  asset.remove('loan_total');
  asset.remove('loan_raised');
  asset.remove('loan_rate');
  asset.remove('loan_duration_months');
  // persist change
  mockAssets[idx] = asset;
  return asset;
}
