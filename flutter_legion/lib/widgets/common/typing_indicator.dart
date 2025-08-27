/// Typing indicators with bouncing dots and pulse effects
/// Shows when minions are processing but haven't started streaming yet
/// 
/// Replicates the React TypingIndicator.tsx with Flutter animations

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../animations/config.dart';

class TypingIndicator extends StatelessWidget {
  final Color? dotColor;
  final double size;
  final Duration? duration;

  const TypingIndicator({
    super.key,
    this.dotColor,
    this.size = 8.0,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveDotColor = dotColor ?? theme.colorScheme.onSurface.withOpacity(0.6);
    final animationDuration = duration ?? const Duration(milliseconds: 1200);

    return SizedBox(
      width: size * 8, // Room for 3 dots + spacing + pulse effect
      height: size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle pulse effect behind dots
          Container(
            width: size * 6,
            height: size * 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: RadialGradient(
                colors: [
                  effectiveDotColor.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.2, 1.2),
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
            )
            .fadeIn(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            )
            .then()
            .fadeOut(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            ),

          // Bouncing dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Container(
                width: size,
                height: size,
                margin: EdgeInsets.symmetric(horizontal: size * 0.2),
                decoration: BoxDecoration(
                  color: effectiveDotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                .moveY(
                  begin: 0,
                  end: -size * 1.5,
                  duration: animationDuration,
                  delay: Duration(milliseconds: index * 200),
                  curve: Curves.easeInOut,
                )
                .then()
                .moveY(
                  begin: -size * 1.5,
                  end: 0,
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                )
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.4, 1.4),
                  duration: animationDuration,
                  delay: Duration(milliseconds: index * 200),
                  curve: Curves.easeInOut,
                )
                .then()
                .scale(
                  begin: const Offset(1.4, 1.4),
                  end: const Offset(1.0, 1.0),
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                )
                .fadeIn(
                  begin: 0.4,
                  duration: animationDuration,
                  delay: Duration(milliseconds: index * 200),
                  curve: Curves.easeInOut,
                )
                .then()
                .fadeOut(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                );
            }),
          ),
        ],
      ),
    );
  }
}

/// Compact typing indicator for smaller spaces
class CompactTypingIndicator extends StatelessWidget {
  final Color? color;
  final double size;

  const CompactTypingIndicator({
    super.key,
    this.color,
    this.size = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return TypingIndicator(
      dotColor: color,
      size: size,
      duration: const Duration(milliseconds: 800),
    );
  }
}

/// Typing indicator with text label
class LabeledTypingIndicator extends StatelessWidget {
  final String label;
  final Color? dotColor;
  final Color? textColor;
  final double dotSize;

  const LabeledTypingIndicator({
    super.key,
    required this.label,
    this.dotColor,
    this.textColor,
    this.dotSize = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface.withOpacity(0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypingIndicator(
          dotColor: dotColor,
          size: dotSize,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: effectiveTextColor,
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .fadeIn(
            begin: 0.7,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          )
          .then()
          .fadeOut(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          ),
      ],
    );
  }
}

/// Typing indicator integrated into a message bubble
class TypingMessageBubble extends StatelessWidget {
  final String senderName;
  final Color? bubbleColor;
  final double dotSize;

  const TypingMessageBubble({
    super.key,
    required this.senderName,
    this.bubbleColor,
    this.dotSize = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBubbleColor = bubbleColor ?? theme.colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: effectiveBubbleColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LabeledTypingIndicator(
            label: 'thinking...',
            dotSize: dotSize,
            dotColor: theme.colorScheme.primary.withOpacity(0.6),
            textColor: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ],
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
      )
      .vistaShimmer(); // Add that delicious Vista shimmer effect
  }
}