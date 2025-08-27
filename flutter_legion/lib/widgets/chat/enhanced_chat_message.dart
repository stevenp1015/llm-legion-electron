/// Enhanced chat message with sophisticated selection system and animations
/// Implements avatar clicking, horizontal slides, diary panels, and tool bubbles
/// 
/// This is the Flutter masterpiece equivalent of React ChatMessage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chat_message.dart';
import '../../models/minion_config.dart';
import '../common/minion_avatar.dart';
import '../common/streaming_text.dart';
import '../common/typing_indicator.dart';
import '../../animations/config.dart';

class EnhancedChatMessage extends StatefulWidget {
  final ChatMessage message;
  final MinionConfig? minionConfig;
  final bool isProcessing;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isBulkDiaryVisible;
  final VoidCallback? onEnterSelectionMode;
  final Function(String, bool)? onToggleSelection; // messageId, shiftKey
  final VoidCallback? onDelete;
  final Function(String)? onEdit;

  const EnhancedChatMessage({
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
  State<EnhancedChatMessage> createState() => _EnhancedChatMessageState();
}

class _EnhancedChatMessageState extends State<EnhancedChatMessage> {
  bool _showDiary = false;
  bool _isEditing = false;
  String _editedContent = '';
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editedContent = widget.message.content;
    _editController.text = _editedContent;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool get _isUser => widget.message.senderType == MessageSender.user;
  bool get _isMinion => widget.message.senderType == MessageSender.ai;
  bool get _isSystem => widget.message.senderType == MessageSender.system;
  bool get _isDiaryVisible => widget.isSelectionMode ? widget.isBulkDiaryVisible : _showDiary;

  // Handle right-click on minion bubbles for diary toggle
  void _handleContextMenu(TapDownDetails details) {
    if (_isMinion && widget.message.internalDiary != null && !widget.isSelectionMode) {
      setState(() {
        _showDiary = !_showDiary;
      });
    }
  }

  // Handle avatar click to enter selection mode
  void _handleAvatarClick() {
    if (!widget.isSelectionMode && widget.onEnterSelectionMode != null) {
      widget.onEnterSelectionMode!();
    }
  }

  // Handle bubble click in selection mode
  void _handleBubbleClick() {
    if (widget.isSelectionMode && widget.onToggleSelection != null) {
      widget.onToggleSelection!(widget.message.id, false); // TODO: Handle shift key
    }
  }

  // Handle double-click to edit user messages
  void _handleDoubleClick() {
    if (_isUser && !widget.isSelectionMode) {
      setState(() {
        _isEditing = true;
        _editController.text = widget.message.content;
      });
    }
  }

  void _handleSaveEdit() {
    if (widget.onEdit != null && _editController.text.trim() != widget.message.content) {
      widget.onEdit!(_editController.text.trim());
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _handleCancelEdit() {
    setState(() {
      _isEditing = false;
      _editController.text = widget.message.content;
    });
  }

  @override
  Widget build(BuildContext context) {
    // System messages get special treatment
    if (_isSystem) {
      return _buildSystemMessage(context);
    }

    // Show typing indicator for processing messages
    if (_isMinion && widget.isProcessing && widget.message.content.trim().isEmpty) {
      return _buildTypingMessage(context);
    }

    return _buildRegularMessage(context);
  }

  Widget _buildSystemMessage(BuildContext context) {
    final theme = Theme.of(context);
    final isError = widget.message.isError ?? false;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isError 
              ? theme.colorScheme.errorContainer.withOpacity(0.3)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError 
                ? theme.colorScheme.error.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          widget.message.content,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isError 
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ).animate()
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .moveY(
          begin: 10,
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        ),
    );
  }

  Widget _buildTypingMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar with typing animation
          TypingMinionAvatar(
            name: widget.message.senderName,
            size: 32,
          ),
          
          const SizedBox(width: 12),
          
          // Typing bubble
          TypingMessageBubble(
            senderName: widget.message.senderName,
          ),
        ],
      ),
    );
  }

  Widget _buildRegularMessage(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTapDown: (details) => _handleContextMenu(details),
      onTap: _handleBubbleClick,
      onDoubleTap: _handleDoubleClick,
      child: AnimatedContainer(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
        // Selection mode slide animation
        transform: Matrix4.identity()
          ..translate(
            widget.isSelectionMode 
                ? (_isUser ? -20.0 : 20.0)
                : 0.0,
          ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left avatar (minions)
              if (!_isUser) _buildAvatar(),
              
              if (!_isUser) const SizedBox(width: 12),
              
              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: _isUser 
                      ? CrossAxisAlignment.end 
                      : CrossAxisAlignment.start,
                  children: [
                    // Diary panel (slides from TOP)
                    if (_isDiaryVisible && _isMinion && widget.message.internalDiary != null)
                      _buildDiaryPanel(context),
                    
                    // Message bubble
                    _buildMessageBubble(context),
                    
                    // Tool call/output bubbles
                    if (widget.message.toolResults != null)
                      _buildToolBubbles(context),
                  ],
                ),
              ),
              
              if (_isUser) const SizedBox(width: 12),
              
              // Right avatar (user)
              if (_isUser) _buildAvatar(),
            ],
          ),
        ),
      ).animate()
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .moveY(
          begin: 10,
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        ),
    );
  }

  Widget _buildAvatar() {
    if (_isUser) {
      return UserAvatar(
        size: 32,
        isSelectable: true,
        isSelected: widget.isSelected,
        showSelectionIndicator: widget.isSelectionMode,
        onTap: _handleAvatarClick,
      );
    } else {
      return MinionAvatar(
        name: widget.message.senderName,
        size: 32,
        isSelectable: true,
        isSelected: widget.isSelected,
        showSelectionIndicator: widget.isSelectionMode,
        onTap: _handleAvatarClick,
      );
    }
  }

  Widget _buildDiaryPanel(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Internal Diary (${widget.message.senderName})',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // TODO: Parse and display diary data properly
          Text(
            widget.message.internalDiary.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    ).animate()
      .slideY(
        begin: -1.0, // Slide from TOP (negative Y)
        duration: SpringConfig.bouncyDuration,
        curve: SpringConfig.bouncy,
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      );
  }

  Widget _buildMessageBubble(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = _getBubbleColor(context);
    final textColor = _getTextColor(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _getBorderRadius(),
        border: widget.isSelected 
            ? Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              )
            : null,
        boxShadow: widget.isSelected 
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message header
          _buildMessageHeader(context, textColor),
          
          const SizedBox(height: 8),
          
          // Message content
          if (_isEditing && _isUser)
            _buildEditingInterface(context)
          else
            ChatStreamingText(
              content: widget.message.content,
              isStreaming: widget.isProcessing,
              isMinion: _isMinion,
              minionColor: textColor,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageHeader(BuildContext context, Color? textColor) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.message.senderName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: textColor ?? theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.message.senderRole != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (textColor ?? theme.colorScheme.primary).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.message.senderRole!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor ?? theme.colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        Text(
          _formatTimestamp(widget.message.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: (textColor ?? theme.colorScheme.onSurface).withOpacity(0.6),
          ),
        ),
        
        // Options menu for user messages (when not in selection mode)
        if (_isUser && !widget.isSelectionMode) ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  setState(() {
                    _isEditing = true;
                  });
                  break;
                case 'delete':
                  widget.onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
            child: Icon(
              Icons.more_vert,
              size: 16,
              color: (textColor ?? theme.colorScheme.onSurface).withOpacity(0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditingInterface(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _handleCancelEdit,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.8),
              ),
            ),
            
            const SizedBox(width: 8),
            
            ElevatedButton.icon(
              onPressed: _handleSaveEdit,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolBubbles(BuildContext context) {
    // TODO: Implement cascading tool call/output bubbles
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.message.toolResults.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate()
      .slideY(
        begin: 0.5, // Slide from bottom
        duration: SpringConfig.slideDuration,
        curve: LegionCurves.toolCascade,
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      );
  }

  Color _getBubbleColor(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isUser) {
      return const Color(0xFFF59E0B); // Amber for user
    }
    
    if (_isMinion && widget.minionConfig?.chatColor != null) {
      try {
        return Color(int.parse(widget.minionConfig!.chatColor!.replaceFirst('#', '0xff')));
      } catch (e) {
        // Fall back to default if parsing fails
      }
    }
    
    return theme.colorScheme.surfaceContainer;
  }

  Color? _getTextColor(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isUser) {
      return Colors.white;
    }
    
    if (_isMinion && widget.minionConfig?.fontColor != null) {
      try {
        return Color(int.parse(widget.minionConfig!.fontColor!.replaceFirst('#', '0xff')));
      } catch (e) {
        // Fall back to default if parsing fails
      }
    }
    
    return theme.colorScheme.onSurface;
  }

  BorderRadius _getBorderRadius() {
    const radius = 18.0;
    
    if (_isUser) {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(4), // Flattened corner
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(4), // Flattened corner  
        bottomRight: Radius.circular(radius),
      );
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