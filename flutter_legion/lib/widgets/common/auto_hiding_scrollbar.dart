/// Auto-hiding scrollbars with fade in/out transitions
/// Provides Vista-style scrollbars that appear during scrolling and fade away
/// 
/// Creates that delicious UX where scrollbars don't clutter the interface

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../animations/config.dart';

class AutoHidingScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final double thickness;
  final double trackThickness;
  final Color? thumbColor;
  final Color? trackColor;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Duration hideDelay;
  final bool isAlwaysShown;

  const AutoHidingScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thickness = 8.0,
    this.trackThickness = 12.0,
    this.thumbColor,
    this.trackColor,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 800),
    this.hideDelay = const Duration(milliseconds: 1500),
    this.isAlwaysShown = false,
  });

  @override
  State<AutoHidingScrollbar> createState() => _AutoHidingScrollbarState();
}

class _AutoHidingScrollbarState extends State<AutoHidingScrollbar>
    with TickerProviderStateMixin {
  
  late ScrollController _scrollController;
  Timer? _hideTimer;
  bool _isScrolling = false;
  bool _isVisible = false;
  late AnimationController _visibilityController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _visibilityController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
    
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    _visibilityController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
        _isVisible = true;
      });
      _visibilityController.forward();
    }

    // Reset the hide timer
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.hideDelay, () {
      if (mounted && !widget.isAlwaysShown) {
        setState(() {
          _isScrolling = false;
          _isVisible = false;
        });
        _visibilityController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScroll();
        return false;
      },
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: widget.isAlwaysShown,
        trackVisibility: false,
        thickness: widget.thickness,
        radius: Radius.circular(widget.thickness / 2),
        child: AnimatedBuilder(
          animation: _visibilityController,
          builder: (context, child) {
            return Stack(
              children: [
                // Main content
                widget.child,
                
                // Custom scrollbar overlay
                if (_isVisible || widget.isAlwaysShown)
                  _buildCustomScrollbar(context, theme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomScrollbar(BuildContext context, ThemeData theme) {
    final thumbColor = widget.thumbColor ?? 
        theme.colorScheme.onSurface.withOpacity(0.4);
    final trackColor = widget.trackColor ?? 
        theme.colorScheme.surfaceContainerHighest.withOpacity(0.2);

    return Positioned(
      right: 4,
      top: 8,
      bottom: 8,
      child: AnimatedContainer(
        duration: widget.fadeInDuration,
        curve: SpringConfig.gentle,
        width: widget.trackThickness,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(widget.trackThickness / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: thumbColor,
            borderRadius: BorderRadius.circular(widget.thickness / 2),
            gradient: LinearGradient(
              colors: [
                thumbColor.withOpacity(0.8),
                thumbColor.withOpacity(0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: thumbColor.withOpacity(0.3),
                blurRadius: 2,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ).animate(target: _isVisible ? 1.0 : 0.0)
        .fadeIn(
          duration: widget.fadeInDuration,
          curve: SpringConfig.gentle,
        )
        .scaleX(
          begin: 0.5,
          duration: widget.fadeInDuration,
          curve: SpringConfig.bouncy,
        )
        .then()
        .animate(target: _isVisible ? 0.0 : 1.0)
        .fadeOut(
          duration: widget.fadeOutDuration,
          curve: SpringConfig.gentle,
        ),
    );
  }
}

/// Auto-hiding Vista-style scrollbar with glass effect
class AutoVistaScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final bool autoHide;

  const AutoVistaScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.autoHide = true,
  });

  @override
  State<AutoVistaScrollbar> createState() => _AutoVistaScrollbarState();
}

class _AutoVistaScrollbarState extends State<AutoVistaScrollbar> {
  bool _isScrolling = false;
  Timer? _hideTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.autoHide) {
          setState(() => _isScrolling = true);
          
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(milliseconds: 2000), () {
            if (mounted) setState(() => _isScrolling = false);
          });
        }
        return false;
      },
      child: Scrollbar(
        controller: widget.controller,
        thumbVisibility: !widget.autoHide || _isScrolling,
        trackVisibility: false,
        thickness: 6,
        radius: const Radius.circular(3),
        child: widget.child,
      ).animate(target: (_isScrolling || !widget.autoHide) ? 1.0 : 0.0)
        .fadeIn(
          duration: const Duration(milliseconds: 200),
          curve: SpringConfig.gentle,
        )
        .then()
        .animate(target: (_isScrolling || !widget.autoHide) ? 0.0 : 1.0)
        .fadeOut(
          duration: const Duration(milliseconds: 800),
          curve: SpringConfig.gentle,
        ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

/// Compact scrollbar for smaller areas
class CompactScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;

  const CompactScrollbar({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AutoHidingScrollbar(
      controller: controller,
      thickness: 4.0,
      trackThickness: 6.0,
      child: child,
    );
  }
}

/// Scrollable area with auto-hiding scrollbars
class ScrollableArea extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ScrollableArea({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return AutoHidingScrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        physics: physics,
        child: child,
      ),
    );
  }
}

/// List with auto-hiding scrollbars
class ScrollableList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Widget? separator;

  const ScrollableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    return AutoHidingScrollbar(
      controller: controller,
      child: ListView.separated(
        controller: controller,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: separator != null 
            ? (context, index) => separator!
            : (context, index) => const SizedBox.shrink(),
        itemBuilder: (context, index) {
          return itemBuilder(context, index, items[index]);
        },
      ),
    );
  }
}

/// Grid with auto-hiding scrollbars
class ScrollableGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final int crossAxisCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const ScrollableGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.controller,
    this.padding,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return AutoHidingScrollbar(
      controller: controller,
      child: GridView.builder(
        controller: controller,
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return itemBuilder(context, index, items[index]);
        },
      ),
    );
  }
}

/// Extension for adding auto-hiding scrollbars to any scrollable widget
extension AutoHidingScrollbarExtension on Widget {
  Widget withAutoHidingScrollbar({
    ScrollController? controller,
    double thickness = 8.0,
    bool autoHide = true,
  }) {
    if (autoHide) {
      return AutoHidingScrollbar(
        controller: controller,
        thickness: thickness,
        child: this,
      );
    } else {
      return AutoVistaScrollbar(
        controller: controller,
        autoHide: false,
        child: this,
      );
    }
  }
}