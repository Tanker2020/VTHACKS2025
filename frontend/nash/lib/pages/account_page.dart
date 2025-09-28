import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/main.dart';
import 'package:nash/pages/login.dart';
import 'package:nash/pages/market_page.dart';

void showToast(BuildContext context, String message,
    {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.of(context);

  final theme = Theme.of(context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 48,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: true,
          child: Container(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.black87,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    try {
      entry.remove();
    } catch (_) {}
  });
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();

  bool _loadingProfile = true;
  bool _loadingFinancial = true;
  int? _nashScore;

  double _totalProfit = 0;
  double _totalLending = 0;
  double _totalBorrowing = 0;
  double _totalBalance = 0;

  List<Map<String, dynamic>> _profitRows = [];
  List<Map<String, dynamic>> _lendingRows = [];
  List<Map<String, dynamic>> _borrowingRows = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinancialData());
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final userId = supabase.auth.currentSession?.user.id;
      if (userId == null) throw AuthException('User not authenticated');

      final profile = await supabase
          .from('profiles')
          .select('username, nashScore, balance')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        _usernameController.text = (profile['username'] ?? '') as String;
        final score = profile['nashScore'];
        if (score is num) _nashScore = score.toInt();
        _totalBalance = (profile['balance'] ?? 0).toDouble();
      }
    } on PostgrestException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (_) {
      if (mounted) showToast(context, 'Unable to load profile', isError: true);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadFinancialData() async {
    setState(() => _loadingFinancial = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw AuthException('User not authenticated');
      final userId = user.id;

      final investments = await supabase
          .from('investments')
          .select('loan_id, selection, outcome, amount, profit_amount, created_at')
          .eq('investor_id', userId) as List<dynamic>;
      final parsedInvestments = investments
          .cast<Map<String, dynamic>>()
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
                'profit_amount': _asDouble(row['profit_amount']),
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      final profitSum = parsedInvestments.fold<double>(
        0,
        (sum, row) => sum + (row['profit_amount'] as double),
      );

      final lendingQuery = await supabase
          .from('bank_market')
          .select('loan_id, amount, outcome, done, settled_at, created_at')
          .eq('lender_id', userId) as List<dynamic>;
      final lendingRows = lendingQuery
          .cast<Map<String, dynamic>>()
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'settled_at': DateTime.tryParse(row['settled_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
                'done': row['done'] == true,
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      final lendingSum = lendingRows.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] as double),
      );

      final borrowingQuery = await supabase
          .from('bank_market')
          .select('loan_id, amount, outcome, done, settled_at, created_at')
          .eq('lendee_id', userId) as List<dynamic>;
      final borrowingRows = borrowingQuery
          .cast<Map<String, dynamic>>()
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'settled_at': DateTime.tryParse(row['settled_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
                'done': row['done'] == true,
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      final borrowingSum = borrowingRows.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] as double),
      );
      // persist profit sum into profiles.profits for this user
      await supabase
          .from('profiles')
          .update({'profits': profitSum})
          .eq('id', userId);

      if (!mounted) return;
      setState(() {
        _profitRows = parsedInvestments;
        _lendingRows = lendingRows;
        _borrowingRows = borrowingRows;
        _totalProfit = profitSum;
        _totalLending = lendingSum;
        _totalBorrowing = borrowingSum;
        _totalBalance = _totalBalance;
      });
    } on PostgrestException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (_) {
      if (mounted) showToast(context, 'Unable to load financial data', isError: true);
    } finally {
      if (mounted) setState(() => _loadingFinancial = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadProfile(),
      _loadFinancialData(),
    ]);
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
      return;
    } catch (_) {
      if (mounted) showToast(context, 'Unexpected error occurred', isError: true);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: _signOut,
        ),
        title: const Text('Account Overview'),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Open market',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () {
              // animated slide transition to MarketPage
              Navigator.of(context).push(PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                reverseTransitionDuration: const Duration(milliseconds: 350),
                pageBuilder: (context, animation, secondaryAnimation) => const MarketPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeInOut));
                  return SlideTransition(position: animation.drive(tween), child: child);
                },
              ));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProfileCard(context),
            const SizedBox(height: 18),
            _buildMetricRow(context),
            const SizedBox(height: 24),
            _buildFinancialTabs(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _usernameController.text.isNotEmpty
        ? _usernameController.text.substring(0, 1).toUpperCase()
        : 'U';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Text(
                initials,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _loadingProfile
                      ? const LinearProgressIndicator(minHeight: 6)
                      : Text(
                          _usernameController.text.isNotEmpty
                              ? _usernameController.text
                              : 'Unknown user',
                          style: theme.textTheme.headlineSmall,
                        ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildNashScoreBadge(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildNashScoreBadge(ThemeData theme) {
    final score = _nashScore?.toString() ?? '—';
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NASH',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.black,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _MetricCard(label: 'Total Profit', value: _totalProfit),
          _MetricCard(label: 'Total Lending', value: _totalLending),
          _MetricCard(label: 'Total Borrowing', value: _totalBorrowing),
          _MetricCard(label: 'Balance', value: _totalBalance),
        ];

        if (_loadingFinancial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (constraints.maxWidth > 720) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cards
                .map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: card)))
                .toList(),
          );
        }

        return Column(
          children: cards
              .map((card) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: card))
              .toList(),
        );
      },
    );
  }

  Widget _buildFinancialTabs(BuildContext context) {
    if (_loadingFinancial) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabBar(
                labelColor: Colors.white,
                indicatorColor: Colors.greenAccent,
                tabs: [
                  Tab(text: 'PROFITS'),
                  Tab(text: 'LENDING'),
                  Tab(text: 'BORROWING'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: TabBarView(
                  children: [
                    _buildTable(_profitRows,
                        columns: const ['Date', 'Loan ID', 'Selection', 'Outcome', 'Amount', 'Profit']),
                    _buildTable(_lendingRows,
                        columns: const ['Date', 'Loan ID', 'Amount', 'Outcome', 'Status', 'Settled']),
                    _buildTable(_borrowingRows,
                        columns: const ['Date', 'Loan ID', 'Amount', 'Outcome', 'Status', 'Settled']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> rows, {required List<String> columns}) {
    if (rows.isEmpty) {
      return const Center(child: Text('No data available yet.'));
    }

    return Scrollbar(
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.4),
        itemBuilder: (context, index) {
          final row = rows[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRowLine(columns[0], _formatDate(row['created_at'])),
                if (columns.contains('Loan ID'))
                  _buildRowLine('Loan ID', row['loan_id']?.toString() ?? '—'),
                if (columns.contains('Selection'))
                  _buildRowLine('Selection', row['selection']?.toString() ?? '—'),
                if (columns.contains('Outcome'))
                  _buildRowLine('Outcome', row['outcome']?.toString() ?? '—'),
                if (columns.contains('Amount'))
                  _buildRowLine('Amount', _formatCurrency(row['amount'])),
                if (columns.contains('Profit'))
                  _buildRowLine('Profit', _formatCurrency(row['profit_amount'])),
                if (columns.contains('Status'))
                  _buildRowLine('Status', row['done'] == true ? 'Complete' : 'Active'),
                if (columns.contains('Settled'))
                  _buildRowLine('Settled', _formatDate(row['settled_at'])),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRowLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return '\$${value.toStringAsFixed(2)}';
    }
    final parsed = double.tryParse(value.toString());
    return parsed != null ? '\$${parsed.toStringAsFixed(2)}' : value.toString();
  }

  String _formatDate(dynamic value) {
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return value?.toString() ?? '—';
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.8)),
            const SizedBox(height: 8),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
