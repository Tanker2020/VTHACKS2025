import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nash/pages/market_builder.dart';
import 'package:nash/pages/other_account_page.dart';
import 'package:nash/data/mock_data.dart';

// Simple vertical dashed divider using CustomPainter
class DashedVerticalDivider extends StatelessWidget {
  final double dashHeight;
  final double gapHeight;
  final Color color;
  const DashedVerticalDivider({Key? key, this.dashHeight = 6, this.gapHeight = 4, this.color = Colors.black26}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(1, double.infinity),
      painter: _DashedVerticalPainter(dashHeight: dashHeight, gapHeight: gapHeight, color: color),
    );
  }
}

class _DashedVerticalPainter extends CustomPainter {
  final double dashHeight;
  final double gapHeight;
  final Color color;
  _DashedVerticalPainter({required this.dashHeight, required this.gapHeight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dashHeight), paint);
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Open Loans';
  String _selectedSort = 'Relevance';

  // build products list from centralized mock assets, resolving borrower info from mock users
  late final List<Map<String, dynamic>> _products = mockAssets.map((a) {
    final m = Map<String, dynamic>.from(a);
    // normalize loan duration key used elsewhere in the UI
    if (m.containsKey('loan_duration_months') && !m.containsKey('loan_duration_days')) {
      m['loan_duration_days'] = m['loan_duration_months'];
    }

    final borrowerId = (m['borrower_id'] as String?);
    final bidder = borrowerId != null ? findUserById(borrowerId) : null;
    if (bidder != null) {
      m['borrower_username'] = bidder['username'];
      m['display_username'] = bidder['display_name'] ?? bidder['username'];
    } else {
      m['display_username'] = m['title'] ?? m['id'].toString();
      m['borrower_username'] = null;
    }
    // ensure price is a string for sorting/parsing elsewhere
    if (m['price'] is! String) m['price'] = m['price']?.toString() ?? '0.00';
    return m;
  }).toList();

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p['category'] == _selectedCategory;
      final matchesQuery = q.isEmpty || p['title'].toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProduct(BuildContext context, Map<String, dynamic> product) {
    final isLoan = product['category'] == 'Open Loans' || product['loan_total'] != null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, sc) {
              return SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(product['title'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('\$${product['price']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isLoan) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color.fromARGB(255, 71, 68, 68), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Borrower', style: Theme.of(context).textTheme.bodySmall),
                            Text(product['borrower_username'] ?? '—', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Raised: \$${(product['loan_raised'] ?? 0).toStringAsFixed(2)}'),
                            Text('Goal: \$${(product['loan_total'] ?? 0).toStringAsFixed(2)}'),
                          ]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Duration: ${product['loan_duration_days'] ?? '—'} mo'),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black26)),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 20),
                    if (isLoan) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          // open contribute dialog
                              final contributed = await showDialog<double?>(
                            context: context,
                            builder: (context) {
                              final amtCtrl = TextEditingController();
                              return AlertDialog(
                                title: const Text('Contribute to loan'),
                                content: TextField(
                                  controller: amtCtrl,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(prefixText: '\$', hintText: 'Amount to contribute'),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      final v = double.tryParse(amtCtrl.text);
                                      Navigator.of(context).pop(v);
                                    },
                                    child: const Text('Contribute'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (contributed != null && contributed > 0) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contributed \$${contributed.toStringAsFixed(2)} to ${product['title']}')));
                          }
                        },
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Contribute'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // navigate to borrower profile using mocked borrower_id / username
                          final bid = product['borrower_id'] as String? ?? product['id'].toString();
                          final bname = product['borrower_username'] as String? ?? product['display_username'] as String? ?? 'guest';
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtherAccountPage(userId: bid, username: bname)));
                        },
                        icon: const Icon(Icons.person_outline),
                        label: const Text('View borrower profile'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product['title']} added to cart')));
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to cart'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ['Open Loans', 'Predictions'];
    final sorts = ['Relevance', 'Price: Low → High', 'Price: High → Low', 'Newest'];
    var items = _filteredProducts;

    // apply sorting
    switch (_selectedSort) {
      case 'Price: Low → High':
        items.sort((a, b) => double.parse(a['price']).compareTo(double.parse(b['price'])));
        break;
      case 'Price: High → Low':
        items.sort((a, b) => double.parse(b['price']).compareTo(double.parse(a['price'])));
        break;
      case 'Newest':
        items.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
        break;
      case 'Relevance':
      default:
        break;
    }

    return Scaffold(
      // allow Scaffold to resize when keyboard appears
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: true,
        actions: [

        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    onSelected: (v) => setState(() => _selectedSort = v),
                    itemBuilder: (_) => sorts
                        .map((s) => PopupMenuItem(value: s, child: Row(children: [Expanded(child: Text(s)), if (_selectedSort == s) const Icon(Icons.check, size: 16)])))
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: categories.map((c) {
                      final selected = c == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            // enforce that one category must always be selected
                            _selectedCategory = c;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('No products found', style: theme.textTheme.titleMedium))
                    : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              // We'll render Open Loans as a horizontal row of cards with dashed separators.
                              final openLoans = items.where((it) => it['category'] == 'Open Loans' || it['category'] == 'Open Loan').toList();

                              // If Open Loans category is selected, show a horizontal Wrap for those items.
                              if (_selectedCategory == 'Open Loans') {
                                // Full-width stacked cards: use vertical Column so each Open Loan uses the full page width.
                                return Column(
                                  children: List.generate(openLoans.length, (idx) {
                                    final p = openLoans[idx];
                                    final seed = idx + (p['title']?.toString().length ?? 0);
                                    final rnd = Random(seed);
                                    final score = rnd.nextInt(101);
                                    final usernameSeed = '${p['title']}_${p['price']}_$idx';
                                    final hashed = usernameSeed.hashCode.toUnsigned(32).toRadixString(16);
                                    final unameLen = hashed.length >= 6 ? 6 : hashed.length;
                                    final displayUsername = 'user_${hashed.substring(0, unameLen)}';
                                    Color bandColor;
                                    if (score < 34) bandColor = Colors.red;
                                    else if (score < 67) bandColor = Colors.yellow.shade700;
                                    else bandColor = Colors.green;
                                    return Column(
                                      children: [
                                        Card(
                                          color: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          child: InkWell(
                                            onTap: () => _openProduct(context, p),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // show username as the primary label instead of product title
                                                  Text(displayUsername, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                                                  const SizedBox(height: 6),
                                                  Text('\$${double.parse(p['price']).toStringAsFixed(0)}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white70)),
                                                  const SizedBox(height: 10),
                                                  Text("Score: $score", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: bandColor) )
                                                  // description below, also on the colored background                                                ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // separator between full-width cards
                                        if (idx < openLoans.length - 1) const SizedBox(height: 8),
                                      ],
                                    );
                                  }),
                                );
                              }
                              // Fallback: render other items in the vertical list as before.
                              final p = items[index];
                              return ListTile(
                                onTap: () => _openProduct(context, p),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                title: Text(p['title'], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('\$${p['price']}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              );
                            },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MarketBuilderPage()),
        ),
        icon: const Icon(Icons.create),
        label: const Text('Create'),
      ),
    );
  }
}
