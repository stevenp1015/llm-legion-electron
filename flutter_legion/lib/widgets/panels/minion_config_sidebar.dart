import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/minion_config.dart';
import '../../providers/app_provider.dart';
import '../../services/legion_api_service.dart';
import 'minion_edit_dialog.dart';

/// A sliding right-side panel for managing minion configurations.
/// This replaces the modal-in-modal pattern with sidebar+modal like Electron.
class MinionConfigSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const MinionConfigSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<MinionConfigSidebar> createState() => _MinionConfigSidebarState();
}

class _MinionConfigSidebarState extends State<MinionConfigSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final service = context.read<LegionApiService>();
    final minions = app.minionConfigs;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth.clamp(320.0, 400.0);

    return Stack(
      children: [
        // Backdrop overlay
        if (widget.isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ).animate().fadeIn(duration: 200.ms),
          ),

        // Sliding panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: widget.isOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(
            elevation: 16,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Roster & Tools',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Minion List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: minions.length,
                      itemBuilder: (ctx, i) {
                        final m = minions[i];
                        final isRegulator = m.role.toLowerCase() == 'regulator';
                        final avatarColor = _parseColor(m.chatColor) ?? 
                            (isRegulator ? Colors.amber : Colors.teal);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isRegulator ? Colors.amber : Colors.teal,
                                width: 3,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: avatarColor,
                              child: Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: _parseColor(m.fontColor) ?? Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              m.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.model,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isRegulator ? Colors.amber : Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  onPressed: () async {
                                    final updated = await MinionEditDialog.show(context, m);
                                    if (updated != null && context.mounted) {
                                      // already updated via provider in dialog
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit ${m.name}',
                                  visualDensity: VisualDensity.compact,
                                ),
                                // Enable/disable switch
                                Switch(
                                  value: m.enabled,
                                  onChanged: (v) async {
                                    final updated = m.copyWith(enabled: v);
                                    await service.updateMinion(updated);
                                    if (context.mounted) {
                                      context.read<AppProvider>().updateMinionConfig(updated);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer with actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Column(
                      children: [
                        // API Keys button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement API key management
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('API Key management coming soon')),
                              );
                            },
                            icon: const Icon(Icons.key),
                            label: const Text('Manage API Keys'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Deploy new minion button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final models = await service.getModelOptions();
                              final keys = await service.getApiKeys();
                              if (!context.mounted) return;
                              
                              final tmp = MinionConfig(
                                id: '',
                                name: 'New Minion',
                                role: 'standard',
                                systemPrompt: 'You are an AI minion created by Steven, the Commander of the Gemini Legion of which you are a member. You are not a boring ass sterile AI assistant, you aim to mimic real authentic human dialogue and conversation flow naturally. Keep your messages relatively brief, like a real-time chat.',
                                model: models.isNotEmpty ? models.first.id : '',
                                apiKeyId: keys.isNotEmpty ? keys.first.id : '',
                                temperature: 0.7,
                                maxTokens: 2000,
                                enabled: true,
                              );
                              final saved = await MinionEditDialog.show(context, tmp);
                              if (saved != null && context.mounted) {
                                final created = await service.addMinion(saved);
                                context.read<AppProvider>().addMinionConfig(created);
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Deploy New Minion'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final colorHex = hex.replaceFirst('#', '');
      if (colorHex.length == 6) {
        return Color(int.parse('FF$colorHex', radix: 16));
      } else if (colorHex.length == 8) {
        return Color(int.parse(colorHex, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
