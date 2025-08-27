/// Streaming text with blinking amber caret
/// Handles Markdown rendering and shows typing caret during streaming
/// 
/// Replicates the React StreamingText.tsx with Flutter markdown and animations

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../animations/config.dart';

class StreamingText extends StatelessWidget {
  final String content;
  final bool isProcessing;
  final Color? textColor;
  final bool isMinion;
  final TextStyle? style;
  final bool enableMarkdown;

  const StreamingText({
    super.key,
    required this.content,
    this.isProcessing = false,
    this.textColor,
    this.isMinion = false,
    this.style,
    this.enableMarkdown = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;
    final effectiveStyle = style ?? theme.textTheme.bodyLarge?.copyWith(
      color: effectiveTextColor,
      height: 1.4,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildContent(context, effectiveStyle),
        ),
        
        // Blinking amber caret when processing
        if (isProcessing && content.isNotEmpty)
          const BlinkingCaret()
            .animate(onPlay: (controller) => controller.repeat())
            .fadeIn(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            )
            .then()
            .fadeOut(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, TextStyle? textStyle) {
    if (!enableMarkdown || !isMinion) {
      // Simple text for user messages or when markdown is disabled
      return SelectableText(
        content,
        style: textStyle,
      );
    }

    // Markdown rendering for minion messages
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context, textStyle),
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (text, href, title) {
        // TODO: Handle link taps
      },
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context, TextStyle? baseStyle) {
    final theme = Theme.of(context);
    
    return MarkdownStyleSheet(
      p: baseStyle,
      h1: baseStyle?.copyWith(
        fontSize: (baseStyle.fontSize ?? 16) * 1.5,
        fontWeight: FontWeight.bold,
      ),
      h2: baseStyle?.copyWith(
        fontSize: (baseStyle.fontSize ?? 16) * 1.3,
        fontWeight: FontWeight.bold,
      ),
      h3: baseStyle?.copyWith(
        fontSize: (baseStyle.fontSize ?? 16) * 1.1,
        fontWeight: FontWeight.w600,
      ),
      code: baseStyle?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        fontSize: (baseStyle.fontSize ?? 16) * 0.9,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      blockquote: baseStyle?.copyWith(
        color: baseStyle.color?.withOpacity(0.7),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      listBullet: baseStyle?.copyWith(
        color: theme.colorScheme.primary,
      ),
      a: baseStyle?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      strong: baseStyle?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      em: baseStyle?.copyWith(
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Blinking amber caret component
class BlinkingCaret extends StatelessWidget {
  final Color? color;
  final double width;
  final double height;

  const BlinkingCaret({
    super.key,
    this.color,
    this.width = 2.0,
    this.height = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFF59E0B); // Amber-500

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(left: 2, top: 2),
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Streaming text specifically for chat messages
class ChatStreamingText extends StatelessWidget {
  final String content;
  final bool isStreaming;
  final bool isMinion;
  final Color? minionColor;

  const ChatStreamingText({
    super.key,
    required this.content,
    this.isStreaming = false,
    this.isMinion = false,
    this.minionColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamingText(
      content: content,
      isProcessing: isStreaming,
      textColor: minionColor,
      isMinion: isMinion,
      enableMarkdown: isMinion, // Only enable markdown for minions
      style: isMinion
          ? null // Use default markdown styling
          : theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white, // User messages are on colored backgrounds
              fontWeight: FontWeight.w400,
            ),
    );
  }
}

/// Simple text with caret for basic use cases
class SimpleStreamingText extends StatelessWidget {
  final String text;
  final bool showCaret;
  final TextStyle? style;

  const SimpleStreamingText({
    super.key,
    required this.text,
    this.showCaret = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return StreamingText(
      content: text,
      isProcessing: showCaret,
      enableMarkdown: false,
      style: style,
    );
  }
}

/// Rich text editor with live caret (for future use)
class LiveTextEditor extends StatefulWidget {
  final String initialText;
  final Function(String)? onChanged;
  final bool showCaret;

  const LiveTextEditor({
    super.key,
    this.initialText = '',
    this.onChanged,
    this.showCaret = true,
  });

  @override
  State<LiveTextEditor> createState() => _LiveTextEditorState();
}

class _LiveTextEditorState extends State<LiveTextEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    widget.onChanged?.call(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: _controller,
      maxLines: null,
      style: theme.textTheme.bodyLarge,
      cursorColor: const Color(0xFFF59E0B), // Amber caret
      cursorWidth: 2,
      cursorRadius: const Radius.circular(1),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}