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
          .select('req_id, amount, end_time, lendee_id, created_at')
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
          .select('id, loan_id, lender_id, lendee_id, amount, outcome, done, settled_at, created_at, bank_arrays');
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
          .select('id, loan_id, amount, selection, outcome, profit_amount, created_at')
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

      await _client.from('investments').insert({
            'investor_id': investorId,
            'loan_id': loanId,
            'amount': amount,
            'selection': selection,
            'entry_price': entryPrice,
            'outcome': 'no',
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
