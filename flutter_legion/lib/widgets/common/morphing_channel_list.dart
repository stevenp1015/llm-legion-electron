/// Morphing channel selection with smooth indicator animations
/// The highlight smoothly slides and morphs between channels
/// 
/// Replicates React's layoutId animation with Flutter Hero/AnimatedPositioned

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/channel.dart';
import '../../animations/config.dart';
import '../../theming/vista_effects.dart';

class MorphingChannelList extends StatefulWidget {
  final List<Channel> channels;
  final String? currentChannelId;
  final Function(String) onChannelSelected;
  final Function(Channel)? onEditChannel;
  final VoidCallback? onCreateChannel;

  const MorphingChannelList({
    super.key,
    required this.channels,
    required this.currentChannelId,
    required this.onChannelSelected,
    this.onEditChannel,
    this.onCreateChannel,
  });

  @override
  State<MorphingChannelList> createState() => _MorphingChannelListState();
}

class _MorphingChannelListState extends State<MorphingChannelList>
    with TickerProviderStateMixin {
  
  final Map<String, GlobalKey> _channelKeys = {};
  String? _previousChannelId;
  
  @override
  void initState() {
    super.initState();
    _ensureKeysForChannels();
  }

  @override
  void didUpdateWidget(MorphingChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeysForChannels();
    
    if (widget.currentChannelId != oldWidget.currentChannelId) {
      _previousChannelId = oldWidget.currentChannelId;
    }
  }

  void _ensureKeysForChannels() {
    for (final channel in widget.channels) {
      _channelKeys.putIfAbsent(channel.id, () => GlobalKey());
    }
  }

  List<Channel> get _dmChannels => 
      widget.channels.where((c) => c.type == ChannelType.dm).toList();
  
  List<Channel> get _groupChannels => 
      widget.channels.where((c) => c.type == ChannelType.userMinionGroup).toList();
  
  List<Channel> get _autoChannels => 
      widget.channels.where((c) => c.type == ChannelType.minionMinionAuto).toList();

  @override
  Widget build(BuildContext context) {
    return VistaGlass(
      opacity: 0.9,
      blurIntensity: 12.0,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Channel sections
            Expanded(
              child: VistaScrollbar(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_dmChannels.isNotEmpty)
                      _buildChannelSection(
                        context,
                        'Direct Messages',
                        _dmChannels,
                        Icons.person,
                        const Color(0xFF0D9488), // Teal
                      ),
                    
                    if (_groupChannels.isNotEmpty)
                      _buildChannelSection(
                        context,
                        'Group Chats',
                        _groupChannels,
                        Icons.group,
                        const Color(0xFFF59E0B), // Amber
                      ),
                    
                    if (_autoChannels.isNotEmpty)
                      _buildChannelSection(
                        context,
                        'Autonomous',
                        _autoChannels,
                        Icons.smart_toy,
                        const Color(0xFF8B5CF6), // Purple
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Channels',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ),
          
          if (widget.onCreateChannel != null)
            VistaTooltip(
              message: 'Create New Channel',
              child: VistaButton(
                onPressed: widget.onCreateChannel,
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.add,
                  size: 20,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelSection(
    BuildContext context,
    String title,
    List<Channel> channels,
    IconData icon,
    Color sectionColor,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: sectionColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: sectionColor.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        // Channel items with morphing indicator
        Stack(
          children: [
            // Morphing background indicator
            _buildMorphingIndicator(channels, sectionColor),
            
            // Channel buttons
            ...channels.map((channel) => _buildChannelItem(
              context,
              channel,
              sectionColor,
            )),
          ],
        ),
        
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMorphingIndicator(List<Channel> channels, Color sectionColor) {
    final currentChannel = channels.firstWhere(
      (c) => c.id == widget.currentChannelId,
      orElse: () => channels.first,
    );
    
    if (widget.currentChannelId == null || 
        !channels.any((c) => c.id == widget.currentChannelId)) {
      return const SizedBox.shrink();
    }

    return AnimatedPositioned(
      duration: SpringConfig.morphDuration,
      curve: LegionCurves.channelMorph,
      left: 12,
      right: 12,
      top: channels.indexOf(currentChannel) * 48.0,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: sectionColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sectionColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: sectionColor.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      ).animate()
        .scale(
          begin: const Offset(0.95, 0.95),
          duration: SpringConfig.morphDuration,
          curve: SpringConfig.morph,
        )
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .vistaShimmer(),
    );
  }

  Widget _buildChannelItem(BuildContext context, Channel channel, Color sectionColor) {
    final theme = Theme.of(context);
    final isActive = widget.currentChannelId == channel.id;
    
    return Container(
      key: _channelKeys[channel.id],
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: VistaButton(
        onPressed: () => widget.onChannelSelected(channel.id),
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Channel icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive 
                    ? sectionColor.withOpacity(0.3)
                    : sectionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getChannelIcon(channel.type),
                size: 16,
                color: isActive 
                    ? sectionColor
                    : sectionColor.withOpacity(0.6),
              ),
            ).animate(target: isActive ? 1.0 : 0.0)
              .rotate(
                begin: 0,
                end: 0.05,
                duration: SpringConfig.hapticDuration,
                curve: SpringConfig.haptic,
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                duration: SpringConfig.hapticDuration,
                curve: SpringConfig.haptic,
              ),
            
            const SizedBox(width: 12),
            
            // Channel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isActive 
                          ? sectionColor
                          : theme.colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (channel.description.isNotEmpty)
                    Flexible(
                      child: Text(
                        channel.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
            
            // Auto mode indicator
            if (channel.type == ChannelType.minionMinionAuto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: channel.isAutoModeActive
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: channel.isAutoModeActive
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  channel.isAutoModeActive ? 'AUTO' : 'PAUSED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: channel.isAutoModeActive
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            
            // Edit button
            if (widget.onEditChannel != null)
              VistaTooltip(
                message: 'Edit ${channel.name}',
                child: IconButton(
                  onPressed: () => widget.onEditChannel!(channel),
                  icon: Icon(
                    Icons.edit,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(
                      isActive ? 0.8 : 0.4,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                ),
              ).animate(target: isActive ? 1.0 : 0.0)
                .fadeIn(
                  duration: SpringConfig.gentleDuration,
                  curve: SpringConfig.gentle,
                )
                .scale(
                  begin: const Offset(0.8, 0.8),
                  duration: SpringConfig.gentleDuration,
                  curve: SpringConfig.gentle,
                ),
          ],
        ),
      ).animate(target: isActive ? 1.0 : 0.0)
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.02, 1.02),
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        ),
    );
  }

  IconData _getChannelIcon(ChannelType type) {
    switch (type) {
      case ChannelType.dm:
        return Icons.person;
      case ChannelType.userMinionGroup:
        return Icons.group;
      case ChannelType.minionMinionAuto:
        return Icons.smart_toy;
      default:
        return Icons.tag;
    }
  }
}

/// Compact channel selector for smaller spaces
class CompactChannelSelector extends StatelessWidget {
  final List<Channel> channels;
  final String? currentChannelId;
  final Function(String) onChannelSelected;

  const CompactChannelSelector({
    super.key,
    required this.channels,
    required this.currentChannelId,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentChannel = channels.firstWhere(
      (c) => c.id == currentChannelId,
      orElse: () => channels.first,
    );

    return VistaButton(
      onPressed: () => _showChannelPicker(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag,
            size: 16,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          Text(
            currentChannel.name,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  void _showChannelPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VistaGlass(
        opacity: 0.95,
        blurIntensity: 15.0,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            final isSelected = channel.id == currentChannelId;
            
            return ListTile(
              leading: Icon(
                Icons.tag,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              title: Text(channel.name),
              subtitle: channel.description.isNotEmpty 
                  ? Text(channel.description)
                  : null,
              selected: isSelected,
              onTap: () {
                onChannelSelected(channel.id);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }
}