import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import '../models/minion_config.dart';
import '../providers/app_provider.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showMacosSheet<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AnalyticsDashboardScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minions = context.watch<AppProvider>().minionConfigs;
    final typography = MacosTheme.of(context).typography;

    return MacosSheet(
      child: SizedBox(
        width: 680,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Analytics Dashboard', style: typography.title1),
                  const Spacer(),
                  PushButton(
                    controlSize: ControlSize.small,
                    secondary: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: minions.isEmpty
                    ? Center(
                        child: Text(
                          'No minion data to display yet.',
                          style: typography.subheadline,
                        ),
                      )
                    : MacosScrollbar(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: minions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _MinionStatCard(minion: minions[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinionStatCard extends StatelessWidget {
  const _MinionStatCard({required this.minion});

  final MinionConfig minion;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    final theme = MacosTheme.of(context);
    final stats = minion.usageStats ?? const UsageStats(
      totalTokens: 0,
      totalRequests: 0,
      totalCost: 0,
      lastUsed: null,
    );
    final nameColor = _parseHexColor(minion.chatColor, theme.primaryColor);
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFF1F1F24)
        : const Color(0xFFF7F7F9);
    final borderColor = theme.dividerColor.withValues(alpha: 0.5);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              minion.name,
              style: typography.title2.copyWith(color: nameColor),
            ),
            const SizedBox(height: 4),
            Text(
              minion.role,
              style: typography.caption1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(label: 'Total Requests', value: stats.totalRequests.toString()),
                _StatItem(label: 'Total Tokens', value: stats.totalTokens.toString()),
                _StatItem(
                  label: 'Total Cost',
                  value: '\$${stats.totalCost.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: typography.headline.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: typography.caption1,
        ),
      ],
    );
  }
}

Color _parseHexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) {
    return fallback;
  }
  final normalized =
      hex.startsWith('#') ? hex.replaceFirst('#', '0xFF') : '0xFF$hex';
  try {
    return Color(int.parse(normalized));
  } catch (_) {
    return fallback;
  }
}
