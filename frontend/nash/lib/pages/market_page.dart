import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/pages/login.dart' as login_page;
import 'package:nash/pages/market_builder.dart';
import 'package:nash/pages/account_page.dart';
import 'package:nash/pages/positions_page.dart';
import 'package:nash/services/supabase_service.dart';
import 'package:nash/widgets/top_navbar.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _sortOption = 'Newest';

  bool _loading = true;
  List<Map<String, dynamic>> _loanRequests = const [];
  List<Map<String, dynamic>> _activeDeals = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final loanRequests = await supabaseService.fetchLoanRequests();
      final deals = await supabaseService.fetchBankDeals();

      // Determine which deals are still active (not done and end_time in future)
      final now = DateTime.now().toUtc();
      final activeDeals = <Map<String, dynamic>>[];
      for (final row in deals) {
        if (row['done'] == true) continue;
        final loanId = row['loan_id'];
        final request = loanRequests.firstWhere(
          (req) => req['req_id'] == loanId,
          orElse: () => {},
        );
        final endTime = request['end_time'];
        final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '');
        DateTime? expiresAt;
        if (createdAt != null && endTime is num && endTime > 0) {
          expiresAt = createdAt.toUtc().add(Duration(days: endTime.toInt()));
        }

        if (expiresAt != null && expiresAt.isBefore(now)) {
          await supabaseService.markBankDealDone(row['id']);
          continue;
        }

        final priceArray = row['bank_arrays'] as List? ?? const [];
        activeDeals.add({
          ...row,
          'loan_request': request,
          'bank_arrays': priceArray.cast<num>(),
        });
      }

      if (!mounted) return;
      _loanRequests = loanRequests;
      _activeDeals = activeDeals;
      _applySort();
    } on PostgrestException catch (error) {
            if (mounted) login_page.showToast(context, error.message, isError: true);
    } catch (_) {
      if (mounted) login_page.showToast(context, 'Unable to load market data', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySort() {
    int compareCreated(Map<String, dynamic> a, Map<String, dynamic> b, {bool descending = true}) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return descending ? db.compareTo(da) : da.compareTo(db);
    }

    int compareAmount(Map<String, dynamic> a, Map<String, dynamic> b, {bool ascending = true}) {
      final qa = _asDouble(a['amount']);
      final qb = _asDouble(b['amount']);
      return ascending ? qa.compareTo(qb) : qb.compareTo(qa);
    }

    int Function(Map<String, dynamic>, Map<String, dynamic>) sorter;
    switch (_sortOption) {
      case 'Oldest':
        sorter = (a, b) => compareCreated(a, b, descending: false);
        break;
      case 'Amount ↑':
        sorter = (a, b) => compareAmount(a, b, ascending: true);
        break;
      case 'Amount ↓':
        sorter = (a, b) => compareAmount(a, b, ascending: false);
        break;
      case 'Newest':
      default:
        sorter = compareCreated;
        break;
    }

    _loanRequests.sort(sorter);
    _activeDeals.sort(sorter);
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((row) {
      final id = row['req_id']?.toString() ?? row['loan_id']?.toString() ?? '';
      final amount = _asDouble(row['amount']).toStringAsFixed(2);
      return id.toLowerCase().contains(query) || amount.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: TopNavbar(
        showBack: true,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketBuilderPage())).then((_) => _loadData()),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('New Request'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            _buildSearchBar(theme),
            const SizedBox(height: 8),
            _buildSortChips(theme),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PositionsPage()),
                ),
                icon: const Icon(Icons.trending_up_outlined),
                label: const Text('My positions'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 80), child: CircularProgressIndicator()))
            else
              DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.18),
                            theme.colorScheme.secondary.withOpacity(0.14),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.55),
                              Colors.white.withOpacity(0.28),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tabs: const [
                          Tab(text: 'OPEN LOANS'),
                          Tab(text: 'INVEST'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: TabBarView(
                        children: [
                          _buildLoanList(theme, _filtered(List<Map<String, dynamic>>.from(_loanRequests)), isLoanRequest: true),
                          _buildInvestList(theme, _filtered(List<Map<String, dynamic>>.from(_activeDeals))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search by borrower or loan id',
            filled: true,
            fillColor: Colors.white.withOpacity(0.12),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChips(ThemeData theme) {
    final options = ['Newest', 'Oldest', 'Amount ↑', 'Amount ↓'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        itemBuilder: (context, index) {
          final opt = options[index];
          final selected = _sortOption == opt;
          return GestureDetector(
            onTap: () {
              setState(() {
                _sortOption = opt;
                _applySort();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: selected
                    ? LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(color: Colors.white.withOpacity(selected ? 0.35 : 0.12)),
                boxShadow: selected
                    ? [
                        BoxShadow(color: theme.colorScheme.primary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))
                      ]
                    : const [],
              ),
              child: Text(
                opt,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: options.length,
      ),
    );
  }

  Widget _buildLoanList(ThemeData theme, List<Map<String, dynamic>> rows, {required bool isLoanRequest}) {
    if (rows.isEmpty) {
      return const Center(child: Text('Nothing to show yet.'));
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final row = rows[index];
        final borrowerProfile = row['lendee_profile'] ?? row['lender_profile'];
        final borrowerUsername = borrowerProfile != null ? 'Anonymous' : null;
        final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
        final formattedDate = createdAt != null
            ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
            : '—';
        final amount = _asDouble(row['amount']);
        final requestId = row['req_id']?.toString() ?? '—';
        final loanId = isLoanRequest ? null : row['loan_id']?.toString();
        final outcome = row['outcome']?.toString();

        final borrowerId = (row['lendee_id'] ?? row['lendee_profile']?['id'])?.toString();
        final lenderId = row['lender_id']?.toString();

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.14),
                    theme.colorScheme.secondary.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          borrowerUsername != null
                              ? borrowerUsername
                              : (isLoanRequest ? 'Request $requestId' : 'Loan ${loanId ?? requestId}'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(formattedDate, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Amount: \$${amount.toStringAsFixed(2)}', style: theme.textTheme.titleLarge?.copyWith(fontSize: 26)),
                  const SizedBox(height: 8),
                  if (isLoanRequest)
                    Row(
                      children: [
                        Chip(label: Text('Duration: ${row['end_time'] ?? '—'} days')),
                        const SizedBox(width: 12),
                        Chip(label: Text('Request ID: $requestId')),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Chip(label: Text('Outcome: ${outcome ?? 'TBD'}')),
                        const SizedBox(width: 12),
                        Chip(label: Text('Loan ID: ${loanId ?? requestId}')),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewAccount(
                          borrowerId,
                          fallbackMessage: 'Borrower profile unavailable',
                        ),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('View borrower'),
                      ),
                      const SizedBox(width: 16),
                      if (!isLoanRequest)
                        TextButton.icon(
                          onPressed: () => _viewAccount(
                            lenderId,
                            fallbackMessage: 'Lender profile unavailable',
                          ),
                          icon: const Icon(Icons.account_balance_outlined),
                          label: const Text('View lender'),
                        ),
                      if (!isLoanRequest) const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (isLoanRequest) {
                            login_page.showToast(context, 'Lending flow coming soon');
                          } else {
                            _showInvestmentSheet(row);
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                        child: Text(isLoanRequest ? 'Lend' : 'Track'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildInvestList(ThemeData theme, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No active deals available.'));
    }

    final now = DateTime.now().toUtc();

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final deal = rows[index];
        final loanId = deal['loan_id']?.toString() ?? '—';
        final amount = _asDouble(deal['amount']);
        final createdAt = DateTime.tryParse(deal['created_at']?.toString() ?? '');
        final createdLabel = createdAt != null
            ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
            : '—';
        final request = deal['loan_request'] as Map<String, dynamic>?;
        final endTime = request?['end_time'];

        DateTime? requestCreatedAt;
        if (request != null) {
          requestCreatedAt = DateTime.tryParse(request['created_at']?.toString() ?? '');
        }

        DateTime? expiresAt;
        if (requestCreatedAt != null && endTime is num) {
          expiresAt = requestCreatedAt.toUtc().add(Duration(days: endTime.toInt()));
        }

        final expiryLabel = expiresAt != null
            ? '${expiresAt.year}-${expiresAt.month.toString().padLeft(2, '0')}-${expiresAt.day.toString().padLeft(2, '0')}'
            : '—';
        final durationLabel = expiresAt != null ? _formatDuration(expiresAt.difference(now)) : '—';

        final rawPriceArray = (deal['bank_arrays'] as List?) ?? const [];
        final priceValues = <double>[];
        for (final value in rawPriceArray) {
          priceValues.add(_asDouble(value));
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary.withOpacity(0.15), theme.colorScheme.secondary.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Loan $loanId', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Ends $expiryLabel', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Amount: \$${amount.toStringAsFixed(2)}', style: theme.textTheme.titleLarge?.copyWith(fontSize: 26)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _metaChip('Lender', 'Anonymous'),
                      _metaChip('Borrower', 'Anonymous'),
                      _metaChip('Created', createdLabel),
                      if (expiresAt != null)
                        _metaChip('Time left', durationLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _viewAccount(
                            deal['lendee_id']?.toString(),
                            fallbackMessage: 'Borrower profile unavailable',
                          ),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('View borrower'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _viewAccount(
                            deal['lender_id']?.toString(),
                            fallbackMessage: 'Lender profile unavailable',
                          ),
                          icon: const Icon(Icons.account_balance_outlined),
                          label: const Text('View lender'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PricePreviewGraph(priceArray: priceValues),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.55),
                            theme.colorScheme.secondary.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: TextButton.icon(
                        onPressed: () => _showInvestmentSheet(deal),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.show_chart_outlined),
                        label: const Text('View price graph'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PositionButton(
                          label: 'Open LONG position',
                          color: Colors.greenAccent,
                          onTap: () => _openPosition(isLong: true, deal: deal),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PositionButton(
                          label: 'Open SHORT position',
                          color: Colors.redAccent,
                          onTap: () => _openPosition(isLong: false, deal: deal),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metaChip(String label, String value) {
    return Chip(
      backgroundColor: Colors.white.withOpacity(0.08),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.18))),
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return 'Expired';
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) return '<1m';
    final minutesDisplay = minutes > 0 ? minutes : totalMinutes;
    return '${minutesDisplay}m';
  }

  void _viewAccount(String? userId, {required String fallbackMessage}) {
    final id = userId;
    if (id == null || id.isEmpty) {
      login_page.showToast(context, fallbackMessage, isError: true);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountPage(
          userId: id,
          readOnly: true,
          anonymousDisplay: true,
        ),
      ),
    );
  }

  void _showInvestmentSheet(Map<String, dynamic> deal) {
    final resolvedDeal = Map<String, dynamic>.from(deal);

    if (resolvedDeal['bank_arrays'] == null) {
      final matching = _activeDeals.firstWhere(
        (element) => element['loan_id'] == deal['loan_id'],
        orElse: () => <String, dynamic>{},
      );
      if (matching.isNotEmpty) {
        resolvedDeal.addAll(matching);
      }
    }

    final rawPrices = (resolvedDeal['bank_arrays'] as List?) ?? const [];
    final priceValues = <double>[];
    for (final value in rawPrices) {
      priceValues.add(_asDouble(value));
    }
    resolvedDeal['bank_arrays'] = priceValues;

    final loanId = resolvedDeal['loan_id']?.toString() ?? '—';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceGraphSheet(
        loanId: loanId,
        priceArray: priceValues,
        onLong: () {
          Navigator.of(context).pop();
          Future.microtask(() => _openPosition(isLong: true, deal: resolvedDeal));
        },
        onShort: () {
          Navigator.of(context).pop();
          Future.microtask(() => _openPosition(isLong: false, deal: resolvedDeal));
        },
      ),
    );
  }

  Future<void> _openPosition({required bool isLong, required Map<String, dynamic> deal}) async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      login_page.showToast(context, 'You must sign in first', isError: true);
      return;
    }

    final amountStr = await showDialog<String?>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Open ${isLong ? 'LONG' : 'SHORT'} position'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Investment Amount (USD)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Confirm')),
          ],
        );
      },
    );

    final amount = double.tryParse(amountStr ?? '');
    if (amount == null || amount <= 0) {
      login_page.showToast(context, 'Invalid amount', isError: true);
      return;
    }

    final priceArray = (deal['bank_arrays'] as List? ?? const []).cast<num>();
    final entryPrice = priceArray.isNotEmpty ? priceArray.last.toDouble() : 1.0;

    try {
      await supabaseService.insertInvestment(
        investorId: userId,
        loanId: deal['loan_id'],
        amount: amount,
        selection: isLong ? 'yes' : 'no',
        entryPrice: entryPrice,
      );
      login_page.showToast(context, 'Position opened successfully');
      await _loadData();
    } on PostgrestException catch (error) {
      login_page.showToast(context, error.message, isError: true);
    } catch (_) {
      login_page.showToast(context, 'Unable to open position', isError: true);
    }
  }
}

class _PositionButton extends StatelessWidget {
  const _PositionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.16),
        foregroundColor: Colors.white,
        shadowColor: color.withOpacity(0.35),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: color.withOpacity(0.55)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PricePreviewGraph extends StatelessWidget {
  const _PricePreviewGraph({
    required this.priceArray,
    this.height = 160,
    this.expanded = false,
  });

  final List<double> priceArray;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.primary.withOpacity(0.22),
          theme.colorScheme.secondary.withOpacity(0.18),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white.withOpacity(0.16)),
    );

    if (priceArray.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: decoration,
          child: Text('No price data yet', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ),
      );
    }

    final effectivePrices = priceArray;
    final spots = <FlSpot>[];
    for (var i = 0; i < effectivePrices.length; i++) {
      spots.add(FlSpot(i.toDouble(), effectivePrices[i]));
    }

    final double minValue = effectivePrices.reduce((a, b) => a < b ? a : b);
    final double maxValue = effectivePrices.reduce((a, b) => a > b ? a : b);
    final double range = (maxValue - minValue).abs();
    final double padding = range < 0.05 ? 0.05 : range * 0.12;

    final double minY = math.max(0.0, minValue - padding);
    final double maxY = math.min(1.2, maxValue + padding);

    final interval = (maxY - minY) / 4;
    final safeInterval = interval <= 0 ? 0.05 : interval;

    final titlesData = FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: expanded,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final dayIndex = value.toInt();
            if (dayIndex < 0 || dayIndex >= effectivePrices.length) {
              return const SizedBox.shrink();
            }
            return Text('D${dayIndex + 1}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11));
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: expanded,
          interval: expanded ? safeInterval.clamp(0.05, 0.25) : 1,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    final gridData = FlGridData(
      show: expanded,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      horizontalInterval: safeInterval,
      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white24, strokeWidth: 1, dashArray: const [4, 4]),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: decoration,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: effectivePrices.length > 1 ? (effectivePrices.length - 1).toDouble() : 1.0,
            minY: minY,
            maxY: maxY,
            gridData: gridData,
            titlesData: titlesData,
            borderData: FlBorderData(show: false),
            lineTouchData: expanded
                ? LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surface.withOpacity(0.85),
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map((spot) => LineTooltipItem(
                                'Day ${spot.x.toInt() + 1}\n${spot.y.toStringAsFixed(3)}',
                                theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(),
                              ))
                          .toList(),
                    ),
                  )
                : LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 4,
                isStrokeCapRound: true,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.35),
                      theme.colorScheme.secondary.withOpacity(0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                dotData: FlDotData(show: expanded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceGraphSheet extends StatelessWidget {
  const _PriceGraphSheet({
    required this.loanId,
    required this.priceArray,
    this.onLong,
    this.onShort,
  });

  final String loanId;
  final List<double> priceArray;
  final VoidCallback? onLong;
  final VoidCallback? onShort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double firstValue = priceArray.isNotEmpty ? priceArray.first : 0.0;
    final double lastValue = priceArray.isNotEmpty ? priceArray.last : 0.0;
    final double delta = lastValue - firstValue;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.94),
            theme.colorScheme.surfaceTint.withOpacity(0.72),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, -12)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Price history · Loan $loanId', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Daily pricing (0-1 scale)', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: _PricePreviewGraph(priceArray: priceArray, height: 220, expanded: true),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatTile(label: 'First', value: firstValue),
                _StatTile(label: 'Last', value: lastValue),
                _StatTile(label: 'Change', value: delta, showSign: true),
              ],
            ),
            if (onLong != null && onShort != null) ...[
              const SizedBox(height: 22),
              Text(
                'Open a position',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PositionButton(
                      label: 'Long position',
                      color: Colors.greenAccent,
                      onTap: onLong!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PositionButton(
                      label: 'Short position',
                      color: Colors.redAccent,
                      onTap: onShort!,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.showSign = false});

  final String label;
  final double value;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedValue = showSign
        ? value >= 0
            ? '+${value.toStringAsFixed(3)}'
            : value.toStringAsFixed(3)
        : value.toStringAsFixed(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(formattedValue, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
