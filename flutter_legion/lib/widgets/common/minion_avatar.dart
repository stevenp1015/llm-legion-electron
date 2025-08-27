/// Gradient minion avatars with hash-based color generation
/// Each minion gets a unique, beautiful gradient based on their name
/// 
/// Replicates the React MinionIcon.tsx with Flutter gradients and shadows

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../animations/config.dart';

class MinionAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isSelectable;
  final bool isSelected;
  final bool showSelectionIndicator;
  final VoidCallback? onTap;
  final bool isUser;

  const MinionAvatar({
    super.key,
    required this.name,
    this.size = 32.0,
    this.isSelectable = false,
    this.isSelected = false,
    this.showSelectionIndicator = false,
    this.onTap,
    this.isUser = false,
  });

  /// Generate a consistent gradient from name hash
  /// Matches the React version's color palette
  static Gradient _nameToGradient(String name) {
    if (name.isEmpty) return _gradients[0];
    
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
      hash = hash & hash; // Ensure 32bit integer
    }
    
    final index = hash.abs() % _gradients.length;
    return _gradients[index];
  }

  /// Beautiful gradient palette matching the React app
  static const List<Gradient> _gradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEF4444), Color(0xFFB91C1C), Color(0xFFBE185D)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFEAB308)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF0D9488)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF2563EB)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6366F1)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFF8B5CF6)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFF97316)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFEAB308)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF84CC16), Color(0xFF65A30D), Color(0xFF16A34A)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF0D9488)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0EA5E9)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF6366F1)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD946EF), Color(0xFFC026D3), Color(0xFFEC4899)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFEF4444)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = isUser ? null : _nameToGradient(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: isSelectable ? onTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main avatar
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: isUser ? null : gradient,
              color: isUser ? const Color(0xFFF59E0B) : null, // Amber for user
              shape: BoxShape.circle,
              boxShadow: [
                // Vista-style double shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 1,
                  spreadRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: isUser
                  ? Icon(
                      Icons.person,
                      color: Colors.white,
                      size: size * 0.5,
                    )
                  : Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Selection indicator circle
          if (showSelectionIndicator)
            Positioned(
              right: isUser ? -12 : null,
              left: isUser ? null : -12,
              top: size / 2 - 8,
              child: AnimatedContainer(
                duration: SpringConfig.hapticDuration,
                curve: SpringConfig.haptic,
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected 
                      ? (isUser ? const Color(0xFFF59E0B) : const Color(0xFF0D9488))
                      : Colors.transparent,
                  border: Border.all(
                    color: isUser ? const Color(0xFFF59E0B) : const Color(0xFF0D9488),
                    width: 2,
                  ),
                ),
              ).animate(target: showSelectionIndicator ? 1.0 : 0.0)
                .scale(
                  duration: SpringConfig.bouncyDuration,
                  curve: SpringConfig.bouncy,
                )
                .fadeIn(
                  duration: SpringConfig.gentleDuration,
                  curve: SpringConfig.gentle,
                ),
            ),
        ],
      ),
    ).animate(target: isSelectable && !showSelectionIndicator ? 1.0 : 0.0)
      .scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.1, 1.1),
        duration: SpringConfig.hapticDuration,
        curve: SpringConfig.haptic,
      );
  }
}

/// User avatar with consistent styling
class UserAvatar extends StatelessWidget {
  final double size;
  final bool isSelectable;
  final bool isSelected;
  final bool showSelectionIndicator;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.size = 32.0,
    this.isSelectable = false,
    this.isSelected = false,
    this.showSelectionIndicator = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MinionAvatar(
      name: 'User', // Will show person icon
      size: size,
      isSelectable: isSelectable,
      isSelected: isSelected,
      showSelectionIndicator: showSelectionIndicator,
      onTap: onTap,
      isUser: true,
    );
  }
}

/// Typing indicator avatar for when minion is processing
class TypingMinionAvatar extends StatelessWidget {
  final String name;
  final double size;

  const TypingMinionAvatar({
    super.key,
    required this.name,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MinionAvatar(name: name, size: size),
        
        // Pulsing indicator
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.6),
                width: 2,
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.2, 1.2),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            )
            .fadeOut(
              begin: 0.6,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
            ),
        ),
      ],
    );
  }
}