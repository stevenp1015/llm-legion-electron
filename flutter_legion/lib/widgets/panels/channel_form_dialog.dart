import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/channel.dart';
import '../../providers/app_provider.dart';
import '../../services/legion_api_service.dart';

class ChannelFormDialog extends StatefulWidget {
  final Channel? initial;

  const ChannelFormDialog({super.key, this.initial});

  static Future<Channel?> show(BuildContext context, {Channel? initial}) {
    return showDialog<Channel>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 640,
          child: ChannelFormDialog(initial: initial),
        ),
      ),
    );
  }

  @override
  State<ChannelFormDialog> createState() => _ChannelFormDialogState();
}

class _ChannelFormDialogState extends State<ChannelFormDialog> {
  late TextEditingController _name;
  late TextEditingController _description;
  ChannelType _type = ChannelType.userMinionGroup;
  final Set<String> _members = {};
  String _memberQuery = '';
  bool _autoModeActive = false;
  String _delayType = 'fixed';
  int _fixedDelay = 5;
  int _randMin = 3;
  int _randMax = 8;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '#new-channel');
    _description = TextEditingController(text: widget.initial?.description ?? '');
    _type = widget.initial?.type ?? ChannelType.userMinionGroup;
    _members.addAll(widget.initial?.members ?? []);
    _autoModeActive = widget.initial?.isAutoModeActive ?? false;
    _delayType = widget.initial?.autoModeDelayType ?? 'fixed';
    _fixedDelay = widget.initial?.autoModeFixedDelay ?? 5;
    _randMin = widget.initial?.autoModeRandomDelay?.min ?? 3;
    _randMax = widget.initial?.autoModeRandomDelay?.max ?? 8;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final service = context.read<LegionApiService>();
    final allNames = {
      LegionApiService.legionCommanderName,
      ...app.allMinionNames,
    }.toList();
    final filteredNames = allNames
        .where((n) => _memberQuery.isEmpty || n.toLowerCase().contains(_memberQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.initial == null ? 'Create Channel' : 'Edit Channel',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name (e.g., #general)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<ChannelType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Channel Type'),
            items: const [
              DropdownMenuItem(value: ChannelType.dm, child: Text('Direct Message')),
              DropdownMenuItem(value: ChannelType.userMinionGroup, child: Text('User + Minions')),
              DropdownMenuItem(value: ChannelType.minionMinionAuto, child: Text('Minion ↔ Minion (Auto)')),
              DropdownMenuItem(value: ChannelType.userOnly, child: Text('User Only')),
            ],
            onChanged: (v) => setState(() {
              _type = v ?? _type;
              if (_type == ChannelType.dm) {
                // Enforce DM constraint: Commander + one minion
                _members
                  ..clear()
                  ..add(LegionApiService.legionCommanderName);
              }
            }),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Members', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search members',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _memberQuery = v),
                ),
              ),
            ],
          ),
          if (_type == ChannelType.dm)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Direct Message: requires you + exactly one minion.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: Scrollbar(
              child: ListView.builder(
                itemCount: filteredNames.length,
                itemBuilder: (ctx, i) {
                  final name = filteredNames[i];
                  final checked = _members.contains(name);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (_type == ChannelType.dm) {
                            // Always include Commander; allow only one additional member
                            _members.add(LegionApiService.legionCommanderName);
                            if (name != LegionApiService.legionCommanderName) {
                              // Keep max 2 members
                              final others = _members
                                  .where((n) => n != LegionApiService.legionCommanderName)
                                  .toList();
                              if (others.length >= 1) {
                                // Replace the existing minion with the new one
                                _members
                                  ..removeWhere((n) => n != LegionApiService.legionCommanderName)
                                  ..add(name);
                              } else {
                                _members.add(name);
                              }
                            }
                          } else {
                            _members.add(name);
                          }
                        } else {
                          _members.remove(name);
                        }
                      });
                    },
                    title: Text(name),
                    dense: true,
                  );
                },
              ),
            ),
          ),

          if (_type == ChannelType.minionMinionAuto) ...[
            const Divider(height: 24),
            SwitchListTile(
              value: _autoModeActive,
              onChanged: (v) => setState(() => _autoModeActive = v),
              title: const Text('Auto-mode Active'),
            ),
            DropdownButtonFormField<String>(
              value: _delayType,
              decoration: const InputDecoration(labelText: 'Auto-mode Delay Type'),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Fixed (seconds)')),
                DropdownMenuItem(value: 'random', child: Text('Random Range (seconds)')),
              ],
              onChanged: (v) => setState(() => _delayType = v ?? 'fixed'),
            ),
            const SizedBox(height: 8),
            if (_delayType == 'fixed')
              TextFormField(
                initialValue: _fixedDelay.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fixed Delay (seconds)'),
                onChanged: (v) => _fixedDelay = int.tryParse(v) ?? _fixedDelay,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _randMin.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min (seconds)'),
                      onChanged: (v) => _randMin = int.tryParse(v) ?? _randMin,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _randMax.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max (seconds)'),
                      onChanged: (v) => _randMax = int.tryParse(v) ?? _randMax,
                    ),
                  ),
                ],
              ),
          ],

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
                  if (_name.text.trim().isEmpty) return;

                  // Enforce DM: Commander + 1 minion
                  final normalizedMembers = () {
                    if (_type == ChannelType.dm) {
                      final set = <String>{LegionApiService.legionCommanderName};
                      final others = _members
                          .where((n) => n != LegionApiService.legionCommanderName)
                          .toList();
                      if (others.isNotEmpty) set.add(others.first);
                      return set.toList();
                    }
                    return _members.toList();
                  }();

                  final data = <String, dynamic>{
                    'id': widget.initial?.id,
                    'name': _name.text.trim(),
                    'description': _description.text.trim(),
                    'type': _type.name.replaceAll('userMinionGroup', 'user_minion_group').replaceAll('minionMinionAuto', 'minion_minion_auto'),
                    'members': normalizedMembers,
                    'isAutoModeActive': _autoModeActive,
                    'autoModeDelayType': _delayType,
                    'autoModeFixedDelay': _delayType == 'fixed' ? _fixedDelay : null,
                    'autoModeRandomDelay': _delayType == 'random' ? {'min': _randMin, 'max': _randMax} : null,
                  };

                  final created = await service.addOrUpdateChannel(data);
                  if (!mounted) return;
                  // Refresh provider channels
                  final channels = await service.getChannels();
                  context.read<AppProvider>().setChannels(channels);
                  Navigator.of(context).pop(created);
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
