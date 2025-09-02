import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/minion_config.dart';
import '../../providers/app_provider.dart';
import '../../services/legion_api_service.dart';
import '../../theming/vista_effects.dart';
import 'minion_edit_dialog.dart';

class MinionConfigPanel extends StatelessWidget {
  const MinionConfigPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 800,
            height: 520,
            child: const _MinionConfigPanelBody(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const _MinionConfigPanelBody();
}

class _MinionConfigPanelBody extends StatelessWidget {
  const _MinionConfigPanelBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final service = context.read<LegionApiService>();
    final minions = app.minionConfigs;

    return VistaPanel(
      title: 'Minion Configurations',
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        )
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Toggle minions, edit details (coming soon).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  itemCount: minions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final m = minions[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Text(m.name.isNotEmpty ? m.name[0] : '?'),
                      ),
                      title: Text(m.name),
                      subtitle: Text('${m.role} • ${m.model}'),
                      trailing: Switch(
                        value: m.enabled,
                        onChanged: (v) async {
                          final updated = m.copyWith(enabled: v);
                          await service.updateMinion(updated);
                          // Reflect in AppProvider
                          // ignore: use_build_context_synchronously
                          context.read<AppProvider>().updateMinionConfig(updated);
                        },
                      ),
                      onTap: () async {
                        final updated = await MinionEditDialog.show(context, m);
                        if (updated != null && context.mounted) {
                          // already updated via provider in dialog; optionally refresh list
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final service = context.read<LegionApiService>();
                  final app = context.read<AppProvider>();
                  // Create a new temporary minion to edit
                  final tmp = MinionConfig(
                    id: '',
                    name: 'New Minion',
                    role: 'standard',
                    systemPrompt: 'You are an AI minion created by Steven, the Commander of the Gemini Legion of which you are a member. You are not a boring ass sterile AI assistant, you aim to mimic real authentic human dialogue and conversation flow naturally. Keep your messages relatively brief, like a real-time chat.',
                    model: (await service.getModelOptions()).first.id,
                    apiKeyId: (await service.getApiKeys()).first.id,
                    temperature: 0.7,
                    maxTokens: 2000,
                    enabled: true,
                  );
                  final saved = await MinionEditDialog.show(context, tmp);
                  if (saved != null && context.mounted) {
                    final created = await service.addMinion(saved);
                    app.addMinionConfig(created);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Deploy New Minion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
