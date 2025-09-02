import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/minion_config.dart';
import '../providers/app_provider.dart';
import '../theming/vista_effects.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AnalyticsDashboardScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minions = context.watch<AppProvider>().minionConfigs;

    return VistaModal(
      onDismiss: () => Navigator.of(context).pop(),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        child: VistaPanel(
          title: 'Analytics Dashboard',
          child: minions.isEmpty
              ? const Center(child: Text('No minion data to display.'))
              : ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    Text(
                      'Minion Performance Overview',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    ...minions.map((minion) => _buildMinionStatCard(context, minion)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMinionStatCard(BuildContext context, MinionConfig minion) {
    final theme = Theme.of(context);
    final stats = minion.usageStats ?? const UsageStats(totalTokens: 0, totalRequests: 0, totalCost: 0, lastUsed: null);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              minion.name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Color(int.parse(minion.chatColor.replaceFirst('#', '0xFF'))),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              minion.role,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Requests', stats.totalRequests.toString()),
                _buildStatItem('Total Tokens', stats.totalTokens.toString()),
                _buildStatItem('Total Cost', '\$${stats.totalCost.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
