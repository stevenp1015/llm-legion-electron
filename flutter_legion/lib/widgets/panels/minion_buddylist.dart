import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/channel.dart';
import '../../models/minion_config.dart';

/// Group 1:1 minion buddy chats by minion name with expand/collapse.
/// Port of MinionBuddylist.tsx from the Electron version.
class MinionBuddyList extends StatefulWidget {
  final List<Channel> channels;
  final List<MinionConfig> minionConfigs;
  final String? currentChannelId;
  final void Function(String channelId) onSelectChannel;
  final void Function(String minionName) onCreateNewChat;
  final void Function(String channelId) onDeleteChannel;

  const MinionBuddyList({
    super.key,
    required this.channels,
    required this.minionConfigs,
    required this.currentChannelId,
    required this.onSelectChannel,
    required this.onCreateNewChat,
    required this.onDeleteChannel,
  });

  @override
  State<MinionBuddyList> createState() => _MinionBuddyListState();
}

class _MinionBuddyListState extends State<MinionBuddyList> {
  final Set<String> _expandedMinions = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter for minion_buddy_chat channels only
    final buddyChats = widget.channels
        .where((c) => c.type == ChannelType.minionBuddyChat)
        .toList();
    
    // Group by minion name
    final minionGroups = <String, List<Channel>>{};
    
    // Initialize all minions (even if no chats yet)
    for (final minion in widget.minionConfigs) {
      minionGroups[minion.name] = [];
    }
    
    // Group existing buddy chats
    for (final chat in buddyChats) {
      // Extract minion name from members (should be [user, minionName])
      final minionName = chat.members.firstWhere(
        (m) => m != 'Legion Commander' && m != 'Steven',
        orElse: () => '',
      );
      if (minionName.isNotEmpty && minionGroups.containsKey(minionName)) {
        minionGroups[minionName]!.add(chat);
      }
    }
    
    // Sort chats within each group by timestamp (newest first)
    for (final chats in minionGroups.values) {
      chats.sort((a, b) {
        final aTime = int.tryParse(a.id.replaceFirst('channel-', '')) ?? 0;
        final bTime = int.tryParse(b.id.replaceFirst('channel-', '')) ?? 0;
        return bTime.compareTo(aTime);
      });
    }
    
    if (minionGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 14,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'MINION BUDDYLIST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        // Minion groups
        ...minionGroups.entries.map((entry) {
          final minionName = entry.key;
          final chats = entry.value;
          final isExpanded = _expandedMinions.contains(minionName);
          final config = widget.minionConfigs.firstWhere(
            (m) => m.name == minionName,
            orElse: () => MinionConfig(
              id: '', name: minionName, role: 'standard',
              systemPrompt: '', model: '', apiKeyId: '',
              temperature: 0.7, maxTokens: 2000, enabled: true,
            ),
          );
          final chatColor = _parseColor(config.chatColor) ?? Colors.teal;

          return Column(
            children: [
              // Minion header row (expandable)
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMinions.remove(minionName);
                    } else {
                      _expandedMinions.add(minionName);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: chatColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          minionName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      Text(
                        '${chats.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Expanded chat list
              if (isExpanded)
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  child: Column(
                    children: [
                      // New chat button
                      InkWell(
                        onTap: () => widget.onCreateNewChat(minionName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                size: 14,
                                color: chatColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'New Chat',
                                style: TextStyle(
                                  color: chatColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Existing chats
                      ...chats.map((chat) {
                        final isActive = widget.currentChannelId == chat.id;
                        return InkWell(
                          onTap: () => widget.onSelectChannel(chat.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? chatColor.withOpacity(0.2) : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 12,
                                  color: isActive 
                                      ? chatColor 
                                      : theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    chat.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive 
                                          ? chatColor 
                                          : theme.textTheme.bodyMedium?.color,
                                      fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Delete button on hover (simplified - always visible)
                                IconButton(
                                  onPressed: () => widget.onDeleteChannel(chat.id),
                                  icon: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: isActive 
                                        ? chatColor.withOpacity(0.7)
                                        : theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                                  ),
                                  iconSize: 14,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(maxWidth: 20, maxHeight: 20),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 100.ms);
                      }),
                    ],
                  ),
                ).animate().fadeIn(duration: 150.ms),
            ],
          );
        }),
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
