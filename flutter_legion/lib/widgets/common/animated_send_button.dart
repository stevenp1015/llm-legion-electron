/// Animated send button with custom loading dots and shimmer effects
/// Features multiple states, icon transitions, and haptic feedback
/// 
/// Replicates the React ChatInput send button with Flutter animations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../animations/config.dart';

enum SendButtonState {
  idle,
  disabled,
  hover,
  sending,
}

class AnimatedSendButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isSending;
  final bool isEnabled;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? disabledColor;

  const AnimatedSendButton({
    super.key,
    this.onPressed,
    this.isSending = false,
    this.isEnabled = true,
    this.tooltip,
    this.size = 48.0,
    this.color,
    this.disabledColor,
  });

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton>
    with TickerProviderStateMixin {
  bool _isHovering = false;
  
  SendButtonState get _currentState {
    if (widget.isSending) return SendButtonState.sending;
    if (!widget.isEnabled) return SendButtonState.disabled;
    if (_isHovering) return SendButtonState.hover;
    return SendButtonState.idle;
  }

  Color _getBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? const Color(0xFFF59E0B); // Amber-500
    final disabledColor = widget.disabledColor ?? primaryColor.withOpacity(0.3);

    switch (_currentState) {
      case SendButtonState.disabled:
        return disabledColor;
      case SendButtonState.sending:
        return const Color(0xFFD97706); // Amber-600
      case SendButtonState.hover:
        return const Color(0xFFD97706); // Amber-600
      case SendButtonState.idle:
        return primaryColor;
    }
  }

  List<BoxShadow> _getBoxShadow(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xFFF59E0B);

    switch (_currentState) {
      case SendButtonState.disabled:
        return [];
      case SendButtonState.sending:
        return [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ];
      case SendButtonState.hover:
        return [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ];
      case SendButtonState.idle:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
    }
  }

  void _handlePressed() {
    if (!widget.isEnabled || widget.isSending) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    widget.onPressed?.call();
  }

  void _handleHoverEnter() {
    setState(() {
      _isHovering = true;
    });
  }

  void _handleHoverExit() {
    setState(() {
      _isHovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: GestureDetector(
        onTapDown: (_) => _handlePressed(),
        child: AnimatedContainer(
          duration: SpringConfig.hapticDuration,
          curve: SpringConfig.haptic,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _getBackgroundColor(context),
            borderRadius: BorderRadius.circular(widget.size * 0.25),
            boxShadow: _getBoxShadow(context),
          ),
          child: Stack(
            children: [
              // Shimmer effect when sending
              if (widget.isSending)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.size * 0.25),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white24,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .moveX(
                      begin: -widget.size,
                      end: widget.size,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.linear,
                    ),
                ),

              // Button content
              Center(
                child: AnimatedSwitcher(
                  duration: SpringConfig.stiffDuration,
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: widget.isSending
                      ? _buildLoadingDots()
                      : _buildSendIcon(),
                ),
              ),
            ],
          ),
        ).animate(target: _isHovering ? 1.0 : 0.0)
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            duration: SpringConfig.hapticDuration,
            curve: SpringConfig.haptic,
          )
          .animate(target: widget.isSending ? 1.0 : 0.0)
          .rotate(
            begin: 0,
            end: -0.1, // Slight rotation when sending
            duration: SpringConfig.gentleDuration,
            curve: SpringConfig.gentle,
          ),
      ),
    );
  }

  Widget _buildSendIcon() {
    return Icon(
      Icons.send,
      key: const ValueKey('send_icon'),
      color: Colors.white,
      size: widget.size * 0.4,
    ).animate(target: _currentState == SendButtonState.hover ? 1.0 : 0.0)
      .rotate(
        begin: 0,
        end: -0.2, // Slight icon rotation on hover
        duration: SpringConfig.hapticDuration,
        curve: SpringConfig.haptic,
      )
      .scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.1, 1.1),
        duration: SpringConfig.hapticDuration,
        curve: SpringConfig.haptic,
      );
  }

  Widget _buildLoadingDots() {
    return SizedBox(
      key: const ValueKey('loading_dots'),
      width: widget.size * 0.6,
      height: widget.size * 0.3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Container(
            width: widget.size * 0.08,
            height: widget.size * 0.08,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.3, 1.3),
              duration: const Duration(milliseconds: 800),
              delay: Duration(milliseconds: index * 150),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.3, 1.3),
              end: const Offset(1.0, 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            )
            .fadeIn(
              begin: 0.6,
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: index * 150),
              curve: Curves.easeInOut,
            )
            .then()
            .fadeOut(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
        }),
      ),
    );
  }
}

/// Compact version for smaller spaces
class CompactSendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSending;
  final bool isEnabled;

  const CompactSendButton({
    super.key,
    this.onPressed,
    this.isSending = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSendButton(
      onPressed: onPressed,
      isSending: isSending,
      isEnabled: isEnabled,
      size: 36.0,
      tooltip: 'Send message',
    );
  }
}

/// Large version for primary actions
class LargeSendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSending;
  final bool isEnabled;
  final String? label;

  const LargeSendButton({
    super.key,
    this.onPressed,
    this.isSending = false,
    this.isEnabled = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicWidth(
      child: Container(
        height: 56.0,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
            ],
            AnimatedSendButton(
              onPressed: onPressed,
              isSending: isSending,
              isEnabled: isEnabled,
              size: 40.0,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only send button for minimal interfaces
class IconSendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSending;
  final bool isEnabled;
  final double size;

  const IconSendButton({
    super.key,
    this.onPressed,
    this.isSending = false,
    this.isEnabled = true,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSendButton(
        onPressed: onPressed,
        isSending: isSending,
        isEnabled: isEnabled,
        size: size,
      ),
    );
  }
}