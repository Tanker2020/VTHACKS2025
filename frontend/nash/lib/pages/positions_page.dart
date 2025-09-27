import 'package:flutter/material.dart';
import 'package:nash/data/mock_data.dart';
import 'package:nash/pages/login.dart' show showToast;

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  @override
  Widget build(BuildContext context) {
    final positions = getUserPositions(currentMockUserId);
    return Scaffold(
      appBar: AppBar(title: const Text('My Positions')),
      body: positions.isEmpty
          ? const Center(child: Text('No open positions'))
          : ListView.separated(
              itemCount: positions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = positions[i];
                final aid = p['assetId'] as int;
                final asset = mockAssets.firstWhere((a) => a['id'] == aid, orElse: () => {});
                final title = asset.isNotEmpty ? asset['title'] : 'Asset #$aid';
                final status = p['status'] as String? ?? 'unknown';
                final qty = (p['qty'] is num) ? (p['qty'] as num).toDouble() : 0.0;
                final entry = (p['entryPrice'] is num) ? (p['entryPrice'] as num).toDouble() : 0.0;
                return ListTile(
                  title: Text(title),
                  subtitle: Text('${p['side']} · Qty: $qty · Entry: ${entry.toStringAsFixed(2)} · Status: $status'),
                  trailing: status == 'open'
                      ? ElevatedButton(
                          onPressed: () {
                            final ok = closePosition(p['id'] as int);
                            if (ok) {
                              setState(() {});
                              showToast(context, 'Position closed');
                            } else {
                              showToast(context, 'Failed to close position', isError: true);
                            }
                          },
                          child: const Text('Close'),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
