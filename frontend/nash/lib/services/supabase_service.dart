import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, username, nashScore, balance, loans, lends, profits, full_name, avatar_url, website')
          .eq('id', userId)
          .maybeSingle();
      return response as Map<String, dynamic>?;
    } on PostgrestException catch (error) {
      _log('fetchProfile', error);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLoanRequests() async {
    try {
      final response = await _client
          .from('loan_req_market')
          .select('req_id, amount, end_time, lendee_id, created_at, updated_at, done')
          .order('created_at');
      return _castList(response);
    } on PostgrestException catch (error) {
      _log('fetchLoanRequests', error);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBankDeals({bool? done}) async {
    try {
      var query = _client
          .from('bank_market')
          .select('id, loan_id, lender_id, lendee_id, amount, outcome, done, created_at, bank_arrays');
      if (done != null) {
        query = query.filter('done', 'eq', done);
      }
      final response = await query.order('created_at', ascending: false);
      return _castList(response);
    } on PostgrestException catch (error) {
      _log('fetchBankDeals', error);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvestmentsForUser(String userId) async {
    try {
      final response = await _client
          .from('investments')
          .select('id, loan_id, amount, selection, outcome, profit_amount, created_at, entry_price, shares')
          .eq('investor_id', userId)
          .order('created_at', ascending: false);
      return _castList(response);
    } on PostgrestException catch (error) {
      _log('fetchInvestmentsForUser', error);
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchProfilesByIds(Iterable<String> ids) async {
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) return {};
    try {
      final formatted = uniqueIds.map((id) => '"$id"').join(',');
      final response = await _client
          .from('profiles')
          .select('id, username, nashScore, balance')
          .filter('id', 'in', '($formatted)');
      final list = _castList(response);
      final map = <String, Map<String, dynamic>>{};
      for (final row in list) {
        final id = row['id']?.toString();
        if (id != null) map[id] = row;
      }
      return map;
    } on PostgrestException catch (error) {
      _log('fetchProfilesByIds', error);
      rethrow;
    }
  }

  Future<void> insertLoanRequest({
    required double amount,
    required int endTime,
    required String lendeeId,
  }) async {
    try {
      await _client.from('loan_req_market').insert({
            'amount': amount,
            'end_time': endTime,
            'lendee_id': lendeeId,
          });
    } on PostgrestException catch (error) {
      _log('insertLoanRequest', error);
      rethrow;
    }
  }

  Future<void> insertInvestment({
    required String investorId,
    required dynamic loanId,
    required double amount,
    required String selection,
    required double entryPrice,
  }) async {
    try {
      final profile = await fetchProfile(investorId);
      final currentBalance = _toDouble(profile?['balance']);
      if (currentBalance < amount) {
        throw PostgrestException(message: 'Insufficient balance', code: 'insufficient_balance', details: null, hint: null);
      }

      final effectivePrice = entryPrice > 0 ? entryPrice : 0.5;
      final shares = amount / effectivePrice;

      await _client.from('investments').insert({
            'investor_id': investorId,
            'loan_id': loanId,
            'amount': amount,
            'selection': selection,
            'entry_price': entryPrice,
            'outcome': 'no',
            'profit_amount': 0,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'shares': shares,
          });

      await _client
          .from('profiles')
          .update({'balance': currentBalance - amount})
          .eq('id', investorId);
    } on PostgrestException catch (error) {
      _log('insertInvestment', error);
      rethrow;
    }
  }

  Future<void> lendToLoanRequest({
    required String lenderId,
    required String lendeeId,
    required String requestId,
    required double amount,
  }) async {
    try {
      final lenderProfile = await fetchProfile(lenderId);
      if (lenderProfile == null) {
        throw PostgrestException(message: 'Lender profile not found', code: 'profile_missing', details: null, hint: null);
      }

      final currentBalance = _toDouble(lenderProfile['balance']);
      if (currentBalance < amount) {
        throw PostgrestException(message: 'Insufficient balance', code: 'insufficient_balance', details: null, hint: null);
      }

      final borrowerProfile = await fetchProfile(lendeeId);
      if (borrowerProfile == null) {
        throw PostgrestException(message: 'Borrower profile not found', code: 'profile_missing', details: null, hint: null);
      }

      final borrowerBalance = _toDouble(borrowerProfile['balance']);
      final newLenderBalance = currentBalance - amount;
      final newBorrowerBalance = borrowerBalance + amount;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await Future.wait([
        _client.from('profiles').update({'balance': newLenderBalance}).eq('id', lenderId),
        _client.from('profiles').update({'balance': newBorrowerBalance}).eq('id', lendeeId),
      ]);

      await _client
          .from('loan_req_market')
          .update({'done': true, 'updated_at': nowIso})
          .eq('req_id', requestId);

      final existing = await _client
          .from('bank_market')
          .select('id')
          .eq('loan_id', requestId)
          .maybeSingle() as Map<String, dynamic>?;

      if (existing != null) {
        await _client
            .from('bank_market')
            .update({
              'outcome': 'in_progress',
              'done': false,
              'lender_id': lenderId,
              'lendee_id': lendeeId,
              'amount': amount,
              'updated_at': nowIso,
            })
            .eq('id', existing['id']);
      } else {
        await _client.from('bank_market').insert({
              'loan_id': requestId,
              'lender_id': lenderId,
              'lendee_id': lendeeId,
              'amount': amount,
              'outcome': 'in_progress',
              'done': false,
              'created_at': nowIso,
              'updated_at': nowIso,
              'bank_arrays': const [],
            });
      }
    } on PostgrestException catch (error) {
      _log('lendToLoanRequest', error);
      rethrow;
    }
  }

  Future<void> payOffLoan({
    required String loanRowId,
    required String loanId,
    required String lenderId,
    required String lendeeId,
    required double amount,
  }) async {
    try {
      final borrowerProfile = await fetchProfile(lendeeId);
      final lenderProfile = await fetchProfile(lenderId);
      if (borrowerProfile == null) {
        throw PostgrestException(message: 'Borrower profile not found', code: 'profile_missing', details: null, hint: null);
      }
      if (lenderProfile == null) {
        throw PostgrestException(message: 'Lender profile not found', code: 'profile_missing', details: null, hint: null);
      }

      final borrowerBalance = _toDouble(borrowerProfile['balance']);
      if (borrowerBalance < amount) {
        throw PostgrestException(message: 'Insufficient balance', code: 'insufficient_balance', details: null, hint: null);
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final investmentsResponse = await _client
          .from('investments')
          .select('id, investor_id, amount, selection, entry_price, shares')
          .eq('loan_id', loanId);
      final investments = _castList(investmentsResponse);

      final profileCache = <String, Map<String, dynamic>>{
        lendeeId: Map<String, dynamic>.from(borrowerProfile),
        lenderId: Map<String, dynamic>.from(lenderProfile),
      };

      Future<Map<String, dynamic>?> loadProfile(String id) async {
        if (profileCache.containsKey(id)) return profileCache[id];
        final fetched = await fetchProfile(id);
        if (fetched != null) {
          profileCache[id] = Map<String, dynamic>.from(fetched);
        }
        return profileCache[id];
      }

      Future<void> applyProfileUpdate(String id, {double? balance, double? profits}) async {
        final update = <String, dynamic>{};
        if (balance != null) update['balance'] = balance;
        if (profits != null) update['profits'] = profits;
        if (update.isEmpty) return;
        await _client.from('profiles').update(update).eq('id', id);
        final cached = profileCache[id] ?? <String, dynamic>{};
        if (balance != null) cached['balance'] = balance;
        if (profits != null) cached['profits'] = profits;
        profileCache[id] = cached;
      }

      double lenderBonusTotal = 0;

      for (final investment in investments) {
        final investorId = investment['investor_id']?.toString();
        if (investorId == null || investorId.isEmpty) continue;

        final investorProfile = await loadProfile(investorId);
        if (investorProfile == null) continue;

        final selection = investment['selection']?.toString().toLowerCase();
        final amountStaked = _toDouble(investment['amount']);
        final savedShares = _toDouble(investment['shares']);
        final entryPrice = _toDouble(investment['entry_price']);
        final effectivePrice = entryPrice > 0 ? entryPrice : 0.5;
        final shares = savedShares > 0 ? savedShares : (amountStaked / effectivePrice);

        final investorBalance = _toDouble(investorProfile['balance']);
        final investorProfits = _toDouble(investorProfile['profits']);

        final wins = selection == 'yes';
        if (wins) {
          final gross = shares;
          final investorCredit = gross * 0.9;
          final lenderBonus = gross * 0.1;
          lenderBonusTotal += lenderBonus;

          final profit = investorCredit - amountStaked;
          await applyProfileUpdate(
            investorId,
            balance: investorBalance + investorCredit,
            profits: investorProfits + profit,
          );
          await _client
              .from('investments')
              .update({
                'outcome': 'won',
                'profit_amount': profit,
                'shares': shares,
              })
              .eq('id', investment['id']);
        } else {
          final loss = -amountStaked;
          await applyProfileUpdate(
            investorId,
            profits: investorProfits + loss,
          );
          await _client
              .from('investments')
              .update({
                'outcome': 'lost',
                'profit_amount': loss,
                'shares': shares,
              })
              .eq('id', investment['id']);
        }
      }

      final borrowerNewBalance = borrowerBalance - amount;
      await applyProfileUpdate(lendeeId, balance: borrowerNewBalance);

      final lenderBalance = _toDouble(lenderProfile['balance']);
      final lenderProfits = _toDouble(lenderProfile['profits']);
      final lenderNewBalance = lenderBalance + amount + lenderBonusTotal;
      final lenderNewProfits = lenderProfits + amount + lenderBonusTotal;
      await applyProfileUpdate(lenderId, balance: lenderNewBalance, profits: lenderNewProfits);

      await _client
          .from('loan_req_market')
          .update({'done': true, 'updated_at': nowIso})
          .eq('req_id', loanId);

      await _client
          .from('bank_market')
          .update({
            'outcome': 'paid',
            'done': true,
            'down': false,
            'updated_at': nowIso,
          })
          .eq('id', loanRowId);

      final borrowerScore = _toDouble(profileCache[lendeeId]?['nashScore']);
      double scoreIncrement = 0;
      if (amount > 0) {
        final ratio = (lenderBonusTotal / amount).clamp(0.0, 1.0);
        scoreIncrement = (0.01 + (0.08 * ratio)).clamp(0.01, 0.09);
      }
      final updatedScore = borrowerScore + scoreIncrement;
      await _client
          .from('profiles')
          .update({'nashScore': updatedScore})
          .eq('id', lendeeId);
    } on PostgrestException {
      rethrow;
    } catch (error) {
      throw PostgrestException(message: error.toString(), code: 'loan_repayment_failed', details: null, hint: null);
    }
  }

  void _log(String op, PostgrestException error) {
    // ignore: avoid_print
    print('[SupabaseService:$op] ${error.message}');
  }

  Future<void> markBankDealDone(dynamic dealId) async {
    try {
      await _client.from('bank_market').update({'done': true}).eq('id', dealId);
    } on PostgrestException catch (error) {
      _log('markBankDealDone', error);
    }
  }

  List<Map<String, dynamic>> _castList(dynamic response) {
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final supabaseService = SupabaseService();
