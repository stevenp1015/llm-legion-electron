import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isSending;
  final bool disabled;
  final String? placeholder;

  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.isSending = false,
    this.disabled = false,
    this.placeholder,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isSending && !widget.disabled) {
      widget.onSendMessage(text);
      _controller.clear();
      setState(() {
        _isComposing = false;
      });
    }
  }

  void _handleTextChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(100),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withAlpha(100),
                  width: _focusNode.hasFocus ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Attachment button (for future MCP tool integration)
                  IconButton(
                    onPressed: widget.disabled ? null : () {
                      // TODO: Show MCP tools menu
                      _showMcpToolsMenu();
                    },
                    icon: Icon(
                      Icons.attach_file,
                      color: widget.disabled
                        ? theme.colorScheme.onSurface.withAlpha(100)
                        : theme.colorScheme.primary,
                    ),
                    tooltip: 'Attach MCP Tools',
                  ),
                  
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !widget.disabled,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: widget.disabled 
                          ? 'Auto-mode active. Input disabled.'
                          : (widget.placeholder ?? 'Message your legion...'),
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                      ),
                      style: theme.textTheme.bodyLarge,
                      onChanged: _handleTextChanged,
                      onSubmitted: (_) => _handleSubmit(),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  
                  // Send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed: (_isComposing && !widget.isSending && !widget.disabled) 
                        ? _handleSubmit 
                        : null,
                      icon: widget.isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ).animate(onPlay: (controller) => controller.repeat())
                            .rotate(duration: 1000.ms)
                        : Icon(
                            Icons.send,
                            color: (_isComposing && !widget.disabled)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withAlpha(150),
                          ),
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ).animate(target: _focusNode.hasFocus ? 1.0 : 0.0)
              .scaleX(begin: 1.0, end: 1.01)
              .shimmer(
                duration: 1500.ms,
                color: theme.colorScheme.primary.withAlpha(50),
              ),
          ),
        ],
      ),
    );
  }

  void _showMcpToolsMenu() {
    // TODO: Implement MCP tools menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 200,
        offset.dx + renderBox.size.width,
        offset.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'file_search',
          child: Row(
            children: [
              Icon(Icons.search),
              SizedBox(width: 8),
              Text('Search Files'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'code_analysis',
          child: Row(
            children: [
              Icon(Icons.code),
              SizedBox(width: 8),
              Text('Code Analysis'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'web_search',
          child: Row(
            children: [
              Icon(Icons.public),
              SizedBox(width: 8),
              Text('Web Search'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        // Handle MCP tool selection
        _insertMcpToolCommand(value);
      }
    });
  }

  void _insertMcpToolCommand(String toolName) {
    final currentText = _controller.text;
    final selection = _controller.selection;
    
    final toolCommand = '/mcp $toolName ';
    
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      toolCommand,
    );
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + toolCommand.length,
    );
    
    setState(() {
      _isComposing = newText.trim().isNotEmpty;
    });
    
    _focusNode.requestFocus();
  }
}