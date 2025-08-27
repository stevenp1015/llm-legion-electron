/// Windows Vista Aero transparency effects for Flutter
/// Because Steven is addicted to that glass-like, translucent gorgeousness
/// 
/// Provides backdrop blurs, gradient overlays, and glass-like surfaces

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../animations/config.dart';

/// Vista Aero glass effect container
class VistaGlass extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blurIntensity;
  final Color? tintColor;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final Border? border;

  const VistaGlass({
    super.key,
    required this.child,
    this.opacity = 0.85,
    this.blurIntensity = 10.0,
    this.tintColor,
    this.shadows,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTintColor = tintColor ?? theme.colorScheme.surface;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveTintColor.withOpacity(opacity),
            borderRadius: effectiveBorderRadius,
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: shadows ?? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 1,
                spreadRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
                Colors.black.withOpacity(0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Vista window-style panel
class VistaPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final double elevation;

  const VistaPanel({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.elevation = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VistaGlass(
      opacity: 0.9,
      blurIntensity: 15.0,
      tintColor: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      shadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: elevation * 2,
          spreadRadius: elevation / 2,
          offset: Offset(0, elevation),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.1),
          blurRadius: 2,
          spreadRadius: 1,
          offset: const Offset(0, -2),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Container(
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
                      title!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ],
          
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Vista taskbar-style bar
class VistaTaskbar extends StatelessWidget {
  final Widget child;
  final double height;

  const VistaTaskbar({
    super.key,
    required this.child,
    this.height = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

/// Vista button with glass effect
class VistaButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const VistaButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.padding,
  });

  @override
  State<VistaButton> createState() => _VistaButtonState();
}

class _VistaButtonState extends State<VistaButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: SpringConfig.hapticDuration,
          curve: SpringConfig.haptic,
          padding: widget.padding ?? const EdgeInsets.symmetric(
            horizontal: 16, 
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPressed 
                  ? [
                      effectiveColor.withOpacity(0.8),
                      effectiveColor.withOpacity(0.6),
                    ]
                  : _isHovering
                      ? [
                          effectiveColor.withOpacity(0.7),
                          effectiveColor.withOpacity(0.5),
                        ]
                      : [
                          effectiveColor.withOpacity(0.6),
                          effectiveColor.withOpacity(0.4),
                        ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(_isHovering ? 0.4 : 0.2),
              width: 1,
            ),
            boxShadow: _isPressed 
                ? [
                    BoxShadow(
                      color: effectiveColor.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    if (_isHovering)
                      BoxShadow(
                        color: effectiveColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w500,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista modal overlay
class VistaModal extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismiss;

  const VistaModal({
    super.key,
    required this.child,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: onDismiss,
          child: Container(
            color: Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
        ),
        
        // Modal content
        Center(
          child: VistaPanel(
            elevation: 16,
            child: child,
          ).animate()
            .scale(
              begin: const Offset(0.8, 0.8),
              duration: SpringConfig.bouncyDuration,
              curve: SpringConfig.bouncy,
            )
            .fadeIn(
              duration: SpringConfig.gentleDuration,
              curve: SpringConfig.gentle,
            ),
        ),
      ],
    );
  }
}

/// Vista tooltip
class VistaTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const VistaTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: theme.textTheme.bodySmall?.copyWith(
        color: Colors.white.withOpacity(0.95),
      ),
      child: child,
    );
  }
}

/// Vista scrollbar
class VistaScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;

  const VistaScrollbar({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thickness: 8,
      radius: const Radius.circular(4),
      thumbVisibility: false, // Auto-hide
      trackVisibility: false,
      child: child,
    );
  }
}

/// Vista loading spinner
class VistaSpinner extends StatelessWidget {
  final double size;
  final Color? color;

  const VistaSpinner({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          effectiveColor.withOpacity(0.7),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
      .rotate(duration: const Duration(seconds: 1))
      .scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.1, 1.1),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
      )
      .then()
      .scale(
        begin: const Offset(1.1, 1.1),
        end: const Offset(0.9, 0.9),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
      );
  }
}

/// Extension for adding Vista effects to any widget
extension VistaEffects on Widget {
  Widget withVistaGlass({
    double opacity = 0.85,
    double blurIntensity = 10.0,
    Color? tintColor,
    BorderRadius? borderRadius,
  }) {
    return VistaGlass(
      opacity: opacity,
      blurIntensity: blurIntensity,
      tintColor: tintColor,
      borderRadius: borderRadius,
      child: this,
    );
  }

  Widget withVistaBlur([double intensity = 10.0]) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: intensity, sigmaY: intensity),
        child: this,
      ),
    );
  }

  Widget withVistaGlow({Color? color, double blurRadius = 12.0}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: (color ?? Colors.blue).withOpacity(0.3),
            blurRadius: blurRadius,
            spreadRadius: blurRadius / 3,
          ),
        ],
      ),
      child: this,
    );
  }
}