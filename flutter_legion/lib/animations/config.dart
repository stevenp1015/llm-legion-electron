/// Centralized animation configuration
/// Because having animations scattered everywhere is fucking chaos
/// 
/// This is the Flutter equivalent of the React animations/config.ts
/// Provides physics-based animation configurations for consistent UX

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animation duration constants (in milliseconds)
class AnimationDuration {
  static const int instant = 100;
  static const int fast = 200;
  static const int normal = 300;
  static const int slow = 500;
}

/// Physics-based animation configurations
/// These mirror the React spring configurations but use Flutter's Curves
class SpringConfig {
  // For UI elements that need to feel responsive
  static const Curve snappy = Curves.easeOutExpo;
  static const Duration snappyDuration = Duration(milliseconds: 200);
  
  // For smooth, gentle animations  
  static const Curve gentle = Curves.easeOutCubic;
  static const Duration gentleDuration = Duration(milliseconds: 300);
  
  // For bouncy, playful animations
  static const Curve bouncy = Curves.elasticOut;
  static const Duration bouncyDuration = Duration(milliseconds: 600);
  
  // For stiff, immediate responses
  static const Curve stiff = Curves.easeOutQuart;
  static const Duration stiffDuration = Duration(milliseconds: 150);
  
  // For satisfying button presses
  static const Curve haptic = Curves.easeOutBack;
  static const Duration hapticDuration = Duration(milliseconds: 200);
  
  // For morphing/shape changes
  static const Curve morph = Curves.easeInOutCubic;
  static const Duration morphDuration = Duration(milliseconds: 400);
  
  // For elastic, rubber-band feel
  static const Curve elastic = Curves.elasticInOut;
  static const Duration elasticDuration = Duration(milliseconds: 800);
  
  // For smooth slides and position changes
  static const Curve slide = Curves.easeOutCirc;
  static const Duration slideDuration = Duration(milliseconds: 350);
}

/// Custom curves that match the React app's feel more closely
class LegionCurves {
  // Vista-style smooth animations
  static const Curve vista = Cubic(0.25, 0.46, 0.45, 0.94);
  
  // Satisfying button press
  static const Curve buttonPress = Cubic(0.68, -0.55, 0.265, 1.55);
  
  // Message entrance with personality
  static const Curve messageEntry = Cubic(0.34, 1.56, 0.64, 1);
  
  // Channel morphing animation
  static const Curve channelMorph = Cubic(0.25, 0.1, 0.25, 1);
  
  // Tool bubble cascade
  static const Curve toolCascade = Cubic(0.175, 0.885, 0.32, 1.275);
}

/// Animation configurations for specific UI patterns
class AnimationVariants {
  // Channel selection with smooth slide + morph
  static Duration get channelSelectionDuration => SpringConfig.morphDuration;
  static Curve get channelSelectionCurve => LegionCurves.channelMorph;
  
  // Message entrance with satisfying bounce
  static Duration get messageEntryDuration => SpringConfig.snappyDuration;
  static Curve get messageEntryCurve => LegionCurves.messageEntry;
  
  // Button interactions that feel tactile
  static Duration get buttonDuration => SpringConfig.hapticDuration;
  static Curve get buttonCurve => SpringConfig.haptic;
  
  // Typing indicator with personality
  static Duration get typingDuration => const Duration(milliseconds: 1200);
  static Curve get typingCurve => Curves.easeInOut;
  
  // Modal/panel slide-in
  static Duration get panelDuration => SpringConfig.slideDuration;
  static Curve get panelCurve => SpringConfig.slide;
  
  // Tool bubble cascade
  static Duration get toolBubbleDuration => const Duration(milliseconds: 400);
  static Curve get toolBubbleCurve => LegionCurves.toolCascade;
  
  // Shimmer effect for loading states
  static Duration get shimmerDuration => const Duration(milliseconds: 1500);
  static Curve get shimmerCurve => Curves.linear;
  
  // Selection mode slide
  static Duration get selectionSlideDuration => SpringConfig.gentleDuration;
  static Curve get selectionSlideCurve => SpringConfig.gentle;
  
  // Diary panel slide from top
  static Duration get diarySlideDuration => SpringConfig.bouncyDuration;
  static Curve get diarySlideCurve => SpringConfig.bouncy;
  
  // Vista aero effects
  static Duration get vistaBlurDuration => SpringConfig.gentleDuration;
  static Curve get vistaBlurCurve => LegionCurves.vista;
}

/// Utility extensions for easier animation usage
extension AnimateExtensions on Widget {
  // Quick access to common animations
  Widget snappy({Duration? delay, Duration? duration}) {
    return animate(delay: delay)
        .fadeIn(duration: duration ?? SpringConfig.snappyDuration, curve: SpringConfig.snappy);
  }
  
  Widget gentle({Duration? delay, Duration? duration}) {
    return animate(delay: delay)
        .fadeIn(duration: duration ?? SpringConfig.gentleDuration, curve: SpringConfig.gentle);
  }
  
  Widget bouncy({Duration? delay, Duration? duration}) {
    return animate(delay: delay)
        .scale(
          duration: duration ?? SpringConfig.bouncyDuration, 
          curve: SpringConfig.bouncy,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
        )
        .fadeIn(duration: duration ?? SpringConfig.bouncyDuration, curve: SpringConfig.bouncy);
  }
  
  Widget hapticPress({Duration? duration}) {
    return animate()
        .scale(
          duration: duration ?? SpringConfig.hapticDuration,
          curve: LegionCurves.buttonPress,
          begin: const Offset(1.0, 1.0),
          end: const Offset(0.95, 0.95),
        );
  }
  
  Widget vistaShimmer({Duration? duration}) {
    return animate()
        .shimmer(
          duration: duration ?? const Duration(milliseconds: 1500),
          color: Colors.white.withOpacity(0.3),
        );
  }
}

/// Staggered animation utilities
class StaggeredAnimations {
  static List<Widget> staggeredList(List<Widget> children, {
    Duration itemDelay = const Duration(milliseconds: 100),
    Duration startDelay = const Duration(milliseconds: 200),
  }) {
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      
      return child.animate(delay: startDelay + (itemDelay * index))
          .fadeIn(duration: SpringConfig.gentleDuration, curve: SpringConfig.gentle)
          .moveY(begin: 10, duration: SpringConfig.gentleDuration, curve: SpringConfig.gentle);
    }).toList();
  }
}

/// Accessibility helper
bool get shouldReduceAnimations {
  return false; // TODO: Check system accessibility settings
}

/// Get animation configuration based on accessibility preferences
Duration getAnimationDuration(String type) {
  if (shouldReduceAnimations) {
    return const Duration(milliseconds: 1);
  }
  
  switch (type) {
    case 'snappy':
      return SpringConfig.snappyDuration;
    case 'gentle':
      return SpringConfig.gentleDuration;
    case 'bouncy':
      return SpringConfig.bouncyDuration;
    case 'haptic':
      return SpringConfig.hapticDuration;
    case 'morph':
      return SpringConfig.morphDuration;
    case 'elastic':
      return SpringConfig.elasticDuration;
    case 'slide':
      return SpringConfig.slideDuration;
    default:
      return SpringConfig.gentleDuration;
  }
}

/// Get animation curve based on type
Curve getAnimationCurve(String type) {
  switch (type) {
    case 'snappy':
      return SpringConfig.snappy;
    case 'gentle':
      return SpringConfig.gentle;
    case 'bouncy':
      return SpringConfig.bouncy;
    case 'haptic':
      return SpringConfig.haptic;
    case 'morph':
      return SpringConfig.morph;
    case 'elastic':
      return SpringConfig.elastic;
    case 'slide':
      return SpringConfig.slide;
    default:
      return SpringConfig.gentle;
  }
}