import 'package:flutter/material.dart';
import 'package:nash/data/mock_data.dart';

class MarketBuilderPage extends StatefulWidget {
  const MarketBuilderPage({super.key});

  @override
  State<MarketBuilderPage> createState() => _MarketBuilderPageState();
}

class _MarketBuilderPageState extends State<MarketBuilderPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  int _durationDays = 6;
  String _urgency = 'Normal'; // Low, Normal, High

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildMarketObject() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return {
      'amount': amount,
      'urgency': _urgency,
      'duration_Days': _durationDays,
      'purpose': _purposeController.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  void _preview() {
    if (!_formKey.currentState!.validate()) return;
    final obj = _buildMarketObject();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Market Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: \$${obj['amount']}', style: Theme.of(context).textTheme.bodyLarge),
            Text('Urgency: ${obj['urgency']}', style: Theme.of(context).textTheme.bodyMedium),
            Text('Duration: ${obj['duration_Days']} Days', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Purpose:', style: Theme.of(context).textTheme.titleSmall),
            Text(obj['purpose'].isNotEmpty ? obj['purpose'] : '—', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submit(obj);
            },
            child: const Text('Submit'),
          )
        ],
      ),
    );
  }

  void _submit(Map<String, dynamic> obj) {
    // Add to in-memory mockAssets as a loan-type asset for local/demo purposes
    final asset = {
      'type': 'loan',
      'title': 'Loan Request — ${obj['purpose'] ?? 'General'}',
      'price': (obj['amount'] as double).toStringAsFixed(2),
      'category': 'Open Loans',
      'urgency': obj['urgency'] ?? 'Normal',
      'loan_total': obj['amount'],
      'loan_raised': 0.0,
      'loan_rate': 5.0,
      'loan_duration_months': obj['duration_Days'],
      'borrower_id': null,
      'created_at': obj['created_at'],
    };
    debugPrint(asset.toString());
    final added = addAsset(asset);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Market request created (#${added['id']}) for \$${obj['amount']}')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Market Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (USD)', prefixText: '\$'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text('Urgency', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: ['Low', 'Normal', 'High'].map((u) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(u),
                      selected: _urgency == u,
                      onSelected: (_) => setState(() => _urgency = u),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duration (Days)', style: theme.textTheme.titleSmall),
                        Slider(
                          value: _durationDays.toDouble(),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          label: '$_durationDays',
                          onChanged: (v) => setState(() => _durationDays = v.round()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: 'Purpose (optional)', hintText: 'What is the loan for?'),
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _preview, child: const Text('Preview'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) _submit(_buildMarketObject()); }, child: const Text('Create'))),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text('Live preview', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Amount: \$${_amountController.text.isNotEmpty ? _amountController.text : '0.00'}', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('Urgency: $_urgency'),
                    const SizedBox(height: 6),
                    Text('Duration: $_durationDays Days'),
                    const SizedBox(height: 8),
                    Text('Purpose: ${_purposeController.text.isNotEmpty ? _purposeController.text : '—'}'),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
