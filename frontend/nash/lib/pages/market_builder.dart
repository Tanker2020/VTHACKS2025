import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/services/supabase_service.dart';

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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onFormChanged);
    _purposeController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _amountController.dispose();
    _purposeController.removeListener(_onFormChanged);
    _purposeController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      _showSnack('You need to be signed in to create a loan request.', isError: true);
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    setState(() => _submitting = true);
    try {
      await supabaseService.insertLoanRequest(
        amount: amount,
        endTime: _durationDays,
        lendeeId: userId,
      );
      if (!mounted) return;
      _showSnack('Loan request submitted successfully.');
      _amountController.clear();
      _purposeController.clear();
      setState(() {
        _durationDays = 6;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        _showSnack(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Unable to submit loan request', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Create Market Request'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withOpacity(0.12), theme.colorScheme.secondary.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 540,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Loan Details', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount (USD)', prefixText: '\$'),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Duration (days)', style: theme.textTheme.titleSmall),
                        Slider(
                          value: _durationDays.toDouble(),
                          min: 2,
                          max: 60,
                          divisions: 58,
                          label: '$_durationDays',
                          onChanged: (value) => setState(() => _durationDays = value.round()),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _purposeController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Purpose (optional)',
                            hintText: 'Describe what this loan will be used for',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Submit Loan Request'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        ),
                        const SizedBox(height: 24),
                        Text('Live Preview', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _LoanPreview(
                          amountText: _amountController.text,
                          duration: _durationDays,
                          purpose: _purposeController.text,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanPreview extends StatelessWidget {
  const _LoanPreview({
    required this.amountText,
    required this.duration,
    required this.purpose,
  });

  final String amountText;
  final int duration;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = double.tryParse(amountText) ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: \$${amount.toStringAsFixed(2)}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Duration: $duration days'),
              const SizedBox(height: 8),
              Text('Purpose: $purpose ', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
