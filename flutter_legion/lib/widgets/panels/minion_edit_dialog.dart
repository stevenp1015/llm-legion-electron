import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/minion_config.dart';
import '../../providers/app_provider.dart';
import '../../services/legion_api_service.dart';
import '../../services/mcp_service.dart';
import '../../models/prompt_preset.dart';

class MinionEditDialog extends StatefulWidget {
  final MinionConfig initial;

  const MinionEditDialog({super.key, required this.initial});

  static Future<MinionConfig?> show(BuildContext context, MinionConfig initial) {
    return showDialog<MinionConfig>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 760,
          child: MinionEditDialog(initial: initial),
        ),
      ),
    );
  }

  @override
  State<MinionEditDialog> createState() => _MinionEditDialogState();
}

class _MinionEditDialogState extends State<MinionEditDialog> {
  late TextEditingController _name;
  late TextEditingController _systemPrompt;
  late TextEditingController _chatColor;
  late TextEditingController _fontColor;
  late TextEditingController _maxTokens;
  double _temperature = 0.7;
  String _model = '';
  String _apiKeyId = '';
  bool _enabled = true;

  bool _isRegulator = false;
  int _regInterval = 10;
  bool _useCustomModel = false;
  String _customModelId = '';

  List<ModelOption> _models = const [];
  List<ApiKey> _apiKeys = const [];
  List<PromptPreset> _presets = const [];
  String? _selectedPresetId;
  String _newPresetName = '';
  Map<String, List<McpTool>> _toolsByServer = const {};
  Set<String> _selectedToolNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: m.name);
    _systemPrompt = TextEditingController(text: m.systemPrompt);
    _chatColor = TextEditingController(text: m.chatColor ?? '');
    _fontColor = TextEditingController(text: m.fontColor ?? '');
    _maxTokens = TextEditingController(text: m.maxTokens.toString());
    _temperature = m.temperature;
    _model = m.model;
    _apiKeyId = m.apiKeyId;
    _enabled = m.enabled;
    _isRegulator = (m.role.toLowerCase() == 'regulator');
    _regInterval = m.regulationInterval ?? 10;
    if (m.mcpTools != null && m.mcpTools!['toolNames'] is List) {
      _selectedToolNames = ((m.mcpTools!['toolNames'] as List).map((e) => e.toString())).toSet();
    }

    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final service = context.read<LegionApiService>();
    final models = await service.getModelOptions();
    final keys = await service.getApiKeys();
    final presets = await service.getPromptPresets();
    final toolsByServer = await service.getAvailableToolsByServer();
    setState(() {
      _models = models;
      _apiKeys = keys;
      _presets = presets;
      _toolsByServer = toolsByServer;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _systemPrompt.dispose();
    _chatColor.dispose();
    _fontColor.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Edit Minion', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _isRegulator ? 'regulator' : 'standard',
                            items: const [
                              DropdownMenuItem(value: 'standard', child: Text('Standard')),
                              DropdownMenuItem(value: 'regulator', child: Text('Regulator')),
                            ],
                            onChanged: (v) => setState(() => _isRegulator = (v == 'regulator')),
                            decoration: const InputDecoration(labelText: 'Role'),
                          ),
                        ),
                      ],
                    ),
                    if (_isRegulator) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _regInterval.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Regulator interval (messages)'),
                        onChanged: (v) => _regInterval = int.tryParse(v) ?? _regInterval,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _useCustomModel ? 'custom-model-entry' : (_model.isNotEmpty ? _model : (_models.isNotEmpty ? _models.first.id : '')),
                                items: [
                                  ..._models.map((m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text('${m.name} (${m.provider})'),
                                      )),
                                  const DropdownMenuItem(value: 'custom-model-entry', child: Text('Custom Model...')),
                                ],
                                onChanged: (v) => setState(() {
                                  if (v == 'custom-model-entry') {
                                    _useCustomModel = true;
                                  } else {
                                    _useCustomModel = false;
                                    _model = v ?? _model;
                                  }
                                }),
                                decoration: const InputDecoration(labelText: 'Model'),
                              ),
                              if (_useCustomModel)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextField(
                                    decoration: const InputDecoration(labelText: 'Custom Model ID'),
                                    onChanged: (v) => _customModelId = v,
                                  ),
                                ),
                              Row(
                                children: [
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      await context.read<LegionApiService>().refreshModelsFromLiteLLM();
                                      final models = await context.read<LegionApiService>().getModelOptions();
                                      if (mounted) setState(() => _models = models);
                                    },
                                    child: const Text('Refresh Models'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _apiKeyId.isNotEmpty ? _apiKeyId : _apiKeys.first.id,
                            items: _apiKeys
                                .map((k) => DropdownMenuItem(
                                      value: k.id,
                                      child: Text('${k.name} (${k.keyPreview})'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _apiKeyId = v ?? _apiKeyId),
                            decoration: const InputDecoration(labelText: 'API Key'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_toolsByServer.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Available MCP Tools'),
                        children: _toolsByServer.entries.map((entry) {
                          final serverId = entry.key;
                          final tools = entry.value;
                          final serverName = tools.isNotEmpty ? (tools.first.serverName ?? serverId) : serverId;
                          return ExpansionTile(
                            title: Text(serverName),
                            children: tools.map((t) => CheckboxListTile(
                                  value: _selectedToolNames.contains(t.name),
                                  onChanged: (v) => setState(() {
                                    if (v == true) _selectedToolNames.add(t.name); else _selectedToolNames.remove(t.name);
                                  }),
                                  title: Text(t.name),
                                  subtitle: t.description != null ? Text(t.description!) : null,
                                )).toList(),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatColor,
                            decoration: const InputDecoration(
                              labelText: 'Chat Color (hex, e.g., #3B82F6)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _fontColor,
                            decoration: const InputDecoration(
                              labelText: 'Font Color (hex, e.g., #FFFFFF)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Temperature'),
                              Slider(
                                value: _temperature,
                                onChanged: (v) => setState(() => _temperature = v),
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label: _temperature.toStringAsFixed(2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxTokens,
                            decoration: const InputDecoration(labelText: 'Max Tokens'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                      title: const Text('Enabled'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPresetId,
                            items: _presets
                                .map((p) => DropdownMenuItem(value: p.id, child: Text('Preset: ${p.name}')))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedPresetId = v;
                              final p = _presets.firstWhere((e) => e.id == v, orElse: () => PromptPreset(id: '', name: '', content: ''));
                              if (p.id.isNotEmpty) _systemPrompt.text = p.content;
                            }),
                            decoration: const InputDecoration(labelText: 'Load a preset'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Manage Presets'),
                                content: SizedBox(
                                  width: 500,
                                  height: 300,
                                  child: ListView(
                                    children: _presets.map((p) => ListTile(
                                      title: Text(p.name),
                                      subtitle: Text(p.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          await context.read<LegionApiService>().deletePromptPreset(p.id);
                                          final updated = await context.read<LegionApiService>().getPromptPresets();
                                          if (mounted) setState(() => _presets = updated);
                                        },
                                      ),
                                    )).toList(),
                                  ),
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                              ),
                            );
                          },
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _systemPrompt,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'System Prompt',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'New preset name'),
                            onChanged: (v) => _newPresetName = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (_newPresetName.trim().isEmpty) return;
                            await context.read<LegionApiService>().addPromptPreset(_newPresetName.trim(), _systemPrompt.text);
                            final updated = await context.read<LegionApiService>().getPromptPresets();
                            setState(() {
                              _presets = updated;
                              _newPresetName = '';
                            });
                          },
                          child: const Text('Save Preset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  // Uniqueness validation
                  final existing = context.read<AppProvider>().minionConfigs;
                  final conflict = existing.any((m) => m.name.toLowerCase() == name.toLowerCase() && m.id != widget.initial.id);
                  if (conflict) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Minion name must be unique.')),
                      );
                    }
                    return;
                  }
                  final modelId = _useCustomModel ? _customModelId.trim() : (_model.isNotEmpty ? _model : (_models.isNotEmpty ? _models.first.id : ''));
                  final updated = widget.initial.copyWith(
                    name: name,
                    role: _isRegulator ? 'regulator' : 'standard',
                    systemPrompt: _systemPrompt.text.isNotEmpty ? _systemPrompt.text : 'You are an AI minion created by Steven, the Commander of the Gemini Legion of which you are a member. You are not a boring ass sterile AI assistant, you aim to mimic real authentic human dialogue and conversation flow naturally. Keep your messages relatively brief, like a real-time chat.',
                    model: modelId,
                    apiKeyId: _apiKeyId,
                    chatColor: _chatColor.text.trim().isEmpty ? null : _chatColor.text.trim(),
                    fontColor: _fontColor.text.trim().isEmpty ? null : _fontColor.text.trim(),
                    temperature: _temperature,
                    maxTokens: int.tryParse(_maxTokens.text.trim()) ?? widget.initial.maxTokens,
                    enabled: _enabled,
                    mcpTools: {
                      'toolNames': _selectedToolNames.toList(),
                    },
                    regulationInterval: _isRegulator ? _regInterval : null,
                  );

                  final service = context.read<LegionApiService>();
                  final saved = await service.updateMinion(updated);
                  if (!mounted) return;
                  context.read<AppProvider>().updateMinionConfig(saved);
                  Navigator.of(context).pop(saved);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
