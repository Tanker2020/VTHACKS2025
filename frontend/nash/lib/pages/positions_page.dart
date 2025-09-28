import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/pages/login.dart';
import 'package:nash/pages/market_page.dart';
import 'package:nash/services/supabase_service.dart';
import 'package:nash/widgets/top_navbar.dart';

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _positions = const [];

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to view positions')), 
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final rows = await supabaseService.fetchInvestmentsForUser(userId);
      if (!mounted) return;
      setState(() {
        _positions = rows
            .where((row) => (row['outcome']?.toString().toLowerCase() ?? 'no') == 'no')
            .toList();
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load positions'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: TopNavbar(
        showBack: true,
        onBack: () => Navigator.of(context).maybePop(),
        onLogout: () async {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        },
        onGoMarket: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MarketPage()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPositions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _positions.isEmpty
                ? const Center(child: Text('No open investments yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: _positions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final row = _positions[index];
                      final amount = _asDouble(row['amount']);
                      final profit = _asDouble(row['profit_amount']);
                      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
                      final formatted = createdAt != null
                          ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
                          : '—';
                      final loanId = row['loan_id'];
                      final selection = row['selection']?.toString().toUpperCase() ?? '—';
                      final outcome = row['outcome']?.toString() ?? 'pending';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Loan #$loanId', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(formatted, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Amount: \$${amount.toStringAsFixed(2)} · Selection: $selection'),
                            const SizedBox(height: 4),
                            Text('Outcome: $outcome · Profit: \$${profit.toStringAsFixed(2)}'),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
