import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chat_message.dart';
import '../../models/minion_config.dart';

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final MinionConfig? minionConfig;
  final bool isProcessing;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isBulkDiaryVisible;
  final VoidCallback? onEnterSelectionMode;
  final Function(bool)? onToggleSelection;
  final VoidCallback? onDelete;
  final Function(String)? onEdit;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.minionConfig,
    this.isProcessing = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isBulkDiaryVisible = false,
    this.onEnterSelectionMode,
    this.onToggleSelection,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onLongPress: isSelectionMode ? null : onEnterSelectionMode,
      onTap: isSelectionMode ? () => onToggleSelection?.call(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getMessageBackgroundColor(context),
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
          boxShadow: isSelected ? [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(50),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ] : [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageHeader(context),
            const SizedBox(height: 8),
            _buildMessageContent(context),
            if (isProcessing) ...[
              const SizedBox(height: 8),
              _buildProcessingIndicator(),
            ],
            if (message.toolResults != null) ...[
              const SizedBox(height: 8),
              _buildToolResults(context),
            ],
          ],
        ),
      ).animate(target: isSelected ? 1.0 : 0.0)
        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.02, 1.02))
        .shimmer(
          duration: 800.ms,
          color: theme.colorScheme.primary.withAlpha(100),
        ),
    );
  }

  Widget _buildMessageHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    message.senderName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getSenderColor(),
                    ),
                  ),
                  if (message.senderRole != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getSenderColor().withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.senderRole!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _getSenderColor(),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isSelectionMode)
          Checkbox(
            value: isSelected,
            onChanged: (value) => onToggleSelection?.call(false),
          ),
        if (!isSelectionMode && message.senderType == MessageSender.user)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  // TODO: Implement edit dialog
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            child: Icon(
              Icons.more_vert,
              color: theme.colorScheme.onSurface.withAlpha(150),
              size: 18,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    final color = _getSenderColor();
    
    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: message.senderType == MessageSender.user
        ? Icon(Icons.person, color: Colors.white, size: 20)
        : message.senderType == MessageSender.system
          ? Icon(Icons.settings, color: Colors.white, size: 20)
          : Text(
              message.senderName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: SelectableText(
        message.content,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: minionConfig?.fontColor != null
            ? Color(int.parse(minionConfig!.fontColor!.replaceFirst('#', '0xff')))
            : theme.colorScheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getSenderColor()),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Processing...',
          style: TextStyle(
            color: _getSenderColor(),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ).animate(onPlay: (controller) => controller.repeat())
      .fadeIn(duration: 800.ms)
      .then()
      .fadeOut(duration: 800.ms);
  }

  Widget _buildToolResults(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Tool Results',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.toolResults.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMessageBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    
    if (minionConfig?.chatColor != null) {
      final color = Color(int.parse(minionConfig!.chatColor!.replaceFirst('#', '0xff')));
      return color.withAlpha(30);
    }
    
    switch (message.senderType) {
      case MessageSender.user:
        return theme.colorScheme.primaryContainer;
      case MessageSender.system:
        return theme.colorScheme.tertiaryContainer;
      case MessageSender.ai:
        return theme.colorScheme.secondaryContainer;
    }
  }

  Color _getSenderColor() {
    if (minionConfig?.chatColor != null) {
      return Color(int.parse(minionConfig!.chatColor!.replaceFirst('#', '0xff')));
    }
    
    switch (message.senderType) {
      case MessageSender.user:
        return const Color(0xFF3B82F6); // Blue
      case MessageSender.system:
        return const Color(0xFF6B7280); // Gray
      case MessageSender.ai:
        return const Color(0xFF10B981); // Green
    }
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}