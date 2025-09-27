import 'package:flutter/material.dart';
import 'package:nash/pages/market_builder.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedSort = 'Relevance';

  final List<Map<String, dynamic>> _products = List.generate(12, (i) => {
        'id': i + 1,
        'title': 'Product ${i + 1}',
        'price': (9.99 + i).toStringAsFixed(2),
        'category': (i % 3 == 0) ? 'Open Loans' : (i % 3 == 1) ? 'Predictions' : 'Other',
        'image': null,
        'description': 'This is a short description of product ${i + 1}. It\'s a lovely item that you will enjoy.'
      });

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p['category'] == _selectedCategory;
      final matchesQuery = q.isEmpty || p['title'].toLowerCase().contains(q) || p['description'].toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProduct(BuildContext context, Map<String, dynamic> product) {
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
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black26)),
                    ),
                    const SizedBox(height: 12),
                    Text(product['description'], style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
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
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    final selected = c == _selectedCategory;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        if (_selectedCategory == c){
                          _selectedCategory = 'All';
                        } else {
                          _selectedCategory = c;
                        }
                      }),
                    );
                  },
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
                          final p = items[index];
                          return ListTile(
                            onTap: () => _openProduct(context, p),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            title: Text(p['title'], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(p['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                            trailing: Column(
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
