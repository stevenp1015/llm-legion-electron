/// Tool call and output bubbles with cascading slide-out animations
/// Features pulsing indicators, expandable content, and staggered reveal
/// 
/// Replicates the React tool bubble system with Flutter sophistication

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../animations/config.dart';
import '../../theming/vista_effects.dart';

/// Tool call data model
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String? description;

  const ToolCall({
    required this.name,
    required this.arguments,
    this.description,
  });
}

/// Tool output data model
class ToolOutput {
  final String content;
  final bool isMarkdown;
  final bool isError;

  const ToolOutput({
    required this.content,
    this.isMarkdown = true,
    this.isError = false,
  });
}

/// Tool call bubble with pulsing indicator when active
class ToolCallBubble extends StatefulWidget {
  final ToolCall toolCall;
  final String minionName;
  final bool isActive;
  final bool isExpandable;
  final VoidCallback? onTap;

  const ToolCallBubble({
    super.key,
    required this.toolCall,
    required this.minionName,
    this.isActive = false,
    this.isExpandable = true,
    this.onTap,
  });

  @override
  State<ToolCallBubble> createState() => _ToolCallBubbleState();
}

class _ToolCallBubbleState extends State<ToolCallBubble> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: VistaGlass(
        opacity: 0.8,
        blurIntensity: 8.0,
        tintColor: const Color(0xFF3B82F6).withOpacity(0.1), // Blue tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
          width: 1,
        ),
        shadows: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(widget.isActive ? 0.3 : 0.1),
            blurRadius: widget.isActive ? 12 : 6,
            spreadRadius: widget.isActive ? 2 : 1,
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isExpandable 
                ? () {
                    setState(() => _isExpanded = !_isExpanded);
                    widget.onTap?.call();
                  }
                : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // Pulsing glow when active
                boxShadow: widget.isActive ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and description
                  Row(
                    children: [
                      // Tool icon with pulsing animation
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.build,
                          size: 16,
                          color: const Color(0xFF3B82F6),
                        ),
                      ).animate(target: widget.isActive ? 1.0 : 0.0)
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.2, 1.2),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .scale(
                          begin: const Offset(1.2, 1.2),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeInOut,
                        ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.minionName} is using tool:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              widget.toolCall.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFamily: 'monospace',
                                color: const Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Expand/collapse indicator
                      if (widget.isExpandable)
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ).animate(target: _isExpanded ? 1.0 : 0.0)
                          .rotate(
                            begin: 0,
                            end: 0.5,
                            duration: SpringConfig.gentleDuration,
                            curve: SpringConfig.gentle,
                          ),
                    ],
                  ),

                  // Expanded details
                  if (_isExpanded) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arguments:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _formatArguments(widget.toolCall.arguments),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ).animate()
                      .slideY(
                        begin: -0.2,
                        duration: SpringConfig.gentleDuration,
                        curve: SpringConfig.gentle,
                      )
                      .fadeIn(
                        duration: SpringConfig.gentleDuration,
                        curve: SpringConfig.gentle,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
      .slideY(
        begin: 0.3, // Slide from below parent
        duration: SpringConfig.slideDuration,
        curve: LegionCurves.toolCascade,
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      )
      // Pulsing glow animation when active
      .animate(target: widget.isActive ? 1.0 : 0.0)
      .shimmer(
        duration: const Duration(milliseconds: 2000),
        color: const Color(0xFF3B82F6).withOpacity(0.3),
      );
  }

  String _formatArguments(Map<String, dynamic> args) {
    try {
      final buffer = StringBuffer();
      args.forEach((key, value) {
        buffer.writeln('$key: ${value.toString()}');
      });
      return buffer.toString().trim();
    } catch (e) {
      return args.toString();
    }
  }
}

/// Tool output bubble with expandable markdown content
class ToolOutputBubble extends StatefulWidget {
  final ToolOutput output;
  final String toolName;
  final bool isExpandable;
  final VoidCallback? onTap;

  const ToolOutputBubble({
    super.key,
    required this.output,
    required this.toolName,
    this.isExpandable = true,
    this.onTap,
  });

  @override
  State<ToolOutputBubble> createState() => _ToolOutputBubbleState();
}

class _ToolOutputBubbleState extends State<ToolOutputBubble> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.output.isError 
        ? const Color(0xFFEF4444) // Red for errors
        : const Color(0xFF10B981); // Green for success

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: VistaGlass(
        opacity: 0.8,
        blurIntensity: 8.0,
        tintColor: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        shadows: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isExpandable 
                ? () {
                    setState(() => _isExpanded = !_isExpanded);
                    widget.onTap?.call();
                  }
                : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          widget.output.isError 
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 16,
                          color: color,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[TOOL OUTPUT]',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Results for ${widget.toolName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (widget.isExpandable)
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ).animate(target: _isExpanded ? 1.0 : 0.0)
                          .rotate(
                            begin: 0,
                            end: 0.5,
                            duration: SpringConfig.gentleDuration,
                            curve: SpringConfig.gentle,
                          ),
                    ],
                  ),

                  // Content preview or full content
                  const SizedBox(height: 8),
                  _isExpanded 
                      ? _buildFullContent(context, color)
                      : _buildPreview(context),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
      .slideY(
        begin: 0.3,
        duration: SpringConfig.slideDuration,
        curve: LegionCurves.toolCascade,
        delay: const Duration(milliseconds: 200), // Slight delay after tool call
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
        delay: const Duration(milliseconds: 200),
      );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = widget.output.content.length > 100
        ? '${widget.output.content.substring(0, 100)}...'
        : widget.output.content;

    return Text(
      previewText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.8),
        fontFamily: widget.output.isMarkdown ? null : 'monospace',
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFullContent(BuildContext context, Color color) {
    if (widget.output.isMarkdown) {
      return _buildMarkdownContent(context, color);
    } else {
      return _buildPlainTextContent(context);
    }
  }

  Widget _buildMarkdownContent(BuildContext context, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: MarkdownBody(
        data: widget.output.content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: theme.textTheme.bodySmall,
          code: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
          codeblockDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        extensionSet: md.ExtensionSet.gitHubFlavored,
      ),
    ).animate()
      .slideY(
        begin: -0.2,
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      );
  }

  Widget _buildPlainTextContent(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        widget.output.content,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    ).animate()
      .slideY(
        begin: -0.2,
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      )
      .fadeIn(
        duration: SpringConfig.gentleDuration,
        curve: SpringConfig.gentle,
      );
  }
}

/// Container for cascading tool bubbles
class ToolBubbleStack extends StatelessWidget {
  final List<ToolCall> toolCalls;
  final List<ToolOutput> toolOutputs;
  final String minionName;
  final Set<String> activeTools;

  const ToolBubbleStack({
    super.key,
    required this.toolCalls,
    required this.toolOutputs,
    required this.minionName,
    this.activeTools = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tool calls
        ...toolCalls.asMap().entries.map((entry) {
          final index = entry.key;
          final toolCall = entry.value;
          
          return ToolCallBubble(
            toolCall: toolCall,
            minionName: minionName,
            isActive: activeTools.contains(toolCall.name),
          ).animate()
            .slideY(
              begin: 0.5,
              duration: SpringConfig.slideDuration,
              curve: LegionCurves.toolCascade,
              delay: Duration(milliseconds: index * 150),
            )
            .fadeIn(
              duration: SpringConfig.gentleDuration,
              curve: SpringConfig.gentle,
              delay: Duration(milliseconds: index * 150),
            );
        }),

        // Tool outputs
        ...toolOutputs.asMap().entries.map((entry) {
          final index = entry.key;
          final output = entry.value;
          final toolName = index < toolCalls.length 
              ? toolCalls[index].name 
              : 'Unknown Tool';
          
          return ToolOutputBubble(
            output: output,
            toolName: toolName,
          ).animate()
            .slideY(
              begin: 0.5,
              duration: SpringConfig.slideDuration,
              curve: LegionCurves.toolCascade,
              delay: Duration(milliseconds: (toolCalls.length + index) * 150),
            )
            .fadeIn(
              duration: SpringConfig.gentleDuration,
              curve: SpringConfig.gentle,
              delay: Duration(milliseconds: (toolCalls.length + index) * 150),
            );
        }),
      ],
    );
  }
}