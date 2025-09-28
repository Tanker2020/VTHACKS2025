import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/main.dart';
import 'package:nash/pages/login.dart' as login_page;
import 'package:nash/pages/market_page.dart';
import 'package:nash/services/supabase_service.dart';
import 'package:nash/widgets/top_navbar.dart';

void showToast(BuildContext context, String message,
    {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

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
                borderRadius: BorderRadius.circular(12),
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
  final String? userId;
  final bool readOnly;
  final bool anonymousDisplay;
  const AccountPage({super.key, this.userId, this.readOnly = false, this.anonymousDisplay = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();

  bool _loadingProfile = true;
  bool _loadingFinancial = true;
  String? _userId;

  int? _nashScore;
  double _balance = 0;

  double _totalProfit = 0;
  double _totalLending = 0;
  double _totalBorrowing = 0;

  List<Map<String, dynamic>> _profitRows = [];
  List<Map<String, dynamic>> _lendingRows = [];
  List<Map<String, dynamic>> _borrowingRows = [];
  String _selectedMetric = 'Profits';

  bool get _isOwnAccount {
    final currentId = supabase.auth.currentUser?.id;
    return !widget.readOnly && currentId != null && currentId == _userId;
  }

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? supabase.auth.currentUser?.id;
    if (_userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToast(context, 'User session not found', isError: true);
      });
    } else {
      _loadProfile();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinancialData());
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_userId == null) return;
    setState(() => _loadingProfile = true);
    try {
      final profile = await supabaseService.fetchProfile(_userId!);
      if (profile != null) {
        _usernameController.text = (profile['username'] ?? '') as String;
        final score = profile['nashScore'];
        if (score is num) _nashScore = score.toInt();
        _balance = _asDouble(profile['balance']);
      }
    } on PostgrestException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (error) {
      if (mounted) showToast(context, 'Unable to load profile', isError: true);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadFinancialData() async {
    if (_userId == null) return;
    setState(() => _loadingFinancial = true);
    try {
      final investments = await supabaseService.fetchInvestmentsForUser(_userId!);
      final parsedInvestments = investments
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
                'profit_amount': _asDouble(row['profit_amount']),
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      final deals = await supabaseService.fetchBankDeals();
      final parsedLending = deals
          .where((row) => row['lender_id'] == _userId)
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'settled_at': DateTime.tryParse(row['settled_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      final parsedBorrowing = deals
          .where((row) => row['lendee_id'] == _userId)
          .map((row) => {
                ...row,
                'created_at': DateTime.tryParse(row['created_at']?.toString() ?? ''),
                'settled_at': DateTime.tryParse(row['settled_at']?.toString() ?? ''),
                'amount': _asDouble(row['amount']),
              })
          .where((row) => row['created_at'] != null)
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime).compareTo(b['created_at'] as DateTime));

      if (!mounted) return;
      setState(() {
        _profitRows = parsedInvestments;
        _lendingRows = parsedLending;
        _borrowingRows = parsedBorrowing;
        _totalProfit = _profitRows.fold<double>(0, (sum, row) => sum + (row['profit_amount'] as double));
        _totalLending = _lendingRows.fold<double>(0, (sum, row) => sum + (row['amount'] as double));
        _totalBorrowing = _borrowingRows.fold<double>(0, (sum, row) => sum + (row['amount'] as double));

        if (_profitRows.isNotEmpty) {
          _selectedMetric = 'Profits';
        } else if (_lendingRows.isNotEmpty) {
          _selectedMetric = 'Lending';
        } else if (_borrowingRows.isNotEmpty) {
          _selectedMetric = 'Borrowing';
        }
      });
    } on PostgrestException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (error) {
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
      MaterialPageRoute(builder: (_) => const login_page.LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavbar(
        showBack: widget.readOnly,
        onBack: () => Navigator.of(context).maybePop(),
        onLogout: _isOwnAccount ? _signOut : null,
        onGoMarket: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MarketPage()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProfileCard(context),
            const SizedBox(height: 16),
            _buildMetricRow(context),
            const SizedBox(height: 24),
            _buildMetricDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final initials = widget.anonymousDisplay
        ? 'A'
        : (_usernameController.text.isNotEmpty
            ? _usernameController.text.substring(0, 1).toUpperCase()
            : 'U');

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
                child: Text(
                  initials,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _loadingProfile
                              ? const LinearProgressIndicator(minHeight: 6)
                              : Text(
                                  widget.anonymousDisplay
                                      ? 'Anonymous'
                                      : (_usernameController.text.isNotEmpty
                                          ? _usernameController.text
                                          : 'Unknown user'),
                                  style: theme.textTheme.headlineSmall,
                                ),
                        ),
                        SizedBox(
                          height: 36,
                          width: 36,
                          child: IconButton(
                            tooltip: 'Refresh',
                            padding: EdgeInsets.zero,
                            onPressed: _refreshAll,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Balance',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70, letterSpacing: 1.4),
                    ),
                    Text(
                      _formatCurrency(_balance),
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 26),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildNashScoreBadge(theme),
            ],
          ),
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
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NASH',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context) {
    if (_loadingFinancial) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: CircularProgressIndicator()));
    }

    final metrics = [
      _MetricCardData('Profits', _totalProfit),
      _MetricCardData('Lending', _totalLending),
      _MetricCardData('Borrowing', _totalBorrowing),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: metrics
                .map(
                  (m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _MetricCard(
                        data: m,
                        isSelected: _selectedMetric == m.label,
                        onTap: () => setState(() => _selectedMetric = m.label),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: metrics
              .map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _MetricCard(
                      data: m,
                      isSelected: _selectedMetric == m.label,
                      onTap: () => setState(() => _selectedMetric = m.label),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricDetails(BuildContext context) {
    final theme = Theme.of(context);
    List<Map<String, dynamic>> rows;
    List<String> columns;

    switch (_selectedMetric) {
      case 'Lending':
        rows = _lendingRows;
        columns = const ['Date', 'Loan ID', 'Amount', 'Outcome', 'Status', 'Settled'];
        break;
      case 'Borrowing':
        rows = _borrowingRows;
        columns = const ['Date', 'Loan ID', 'Amount', 'Outcome', 'Status', 'Settled'];
        break;
      case 'Profits':
      default:
        rows = _profitRows;
        columns = const ['Date', 'Loan ID', 'Selection', 'Outcome', 'Amount', 'Profit'];
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          padding: const EdgeInsets.all(18),
          child: rows.isEmpty
              ? const Center(child: Text('No data available yet.'))
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: columns
                              .map(
                                (label) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: _buildRowLine(
                                    label,
                                    _valueForColumn(label, row),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  String _valueForColumn(String label, Map<String, dynamic> row) {
    switch (label) {
      case 'Date':
        return _formatDate(row['created_at']);
      case 'Loan ID':
        return row['loan_id']?.toString() ?? '—';
      case 'Selection':
        return row['selection']?.toString() ?? '—';
      case 'Outcome':
        return row['outcome']?.toString() ?? '—';
      case 'Amount':
        return _formatCurrency(row['amount']);
      case 'Profit':
        return _formatCurrency(row['profit_amount']);
      case 'Status':
        return row['done'] == true ? 'Complete' : 'Active';
      case 'Settled':
        return _formatDate(row['settled_at']);
      default:
        return row[label]?.toString() ?? '—';
    }
  }

  Widget _buildRowLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
}

class _MetricCardData {
  const _MetricCardData(this.label, this.value);
  final String label;
  final double value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data, required this.isSelected, required this.onTap});

  final _MetricCardData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isSelected ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.07);
    final borderColor = isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.08);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: 8),
                Text(
                  '\$${data.value.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
