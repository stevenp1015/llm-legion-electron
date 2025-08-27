/// Floating selection header with bouncy entrance animation
/// Shows Delete, Show Diary, and Done buttons when messages are selected
/// 
/// Replicates the React SelectionHeader.tsx with Flutter animations

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../animations/config.dart';

class SelectionHeader extends StatelessWidget {
  final bool isVisible;
  final int selectedCount;
  final bool hasMinions;
  final VoidCallback onDelete;
  final VoidCallback onShowDiary;
  final VoidCallback onDone;

  const SelectionHeader({
    super.key,
    required this.isVisible,
    required this.selectedCount,
    required this.hasMinions,
    required this.onDelete,
    required this.onShowDiary,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B), // Amber-500
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD97706), // Amber-600
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 4,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$selectedCount message${selectedCount != 1 ? 's' : ''} selected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate()
                .fadeIn(
                  duration: SpringConfig.gentleDuration,
                  curve: SpringConfig.gentle,
                )
                .scale(
                  begin: const Offset(0.8, 0.8),
                  duration: SpringConfig.bouncyDuration,
                  curve: SpringConfig.bouncy,
                ),

              const SizedBox(width: 16),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.delete,
                    onPressed: onDelete,
                    color: const Color(0xFFEF4444), // Red-500
                    tooltip: 'Delete selected messages',
                    delay: 100,
                  ),
                  
                  if (hasMinions) ...[
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.book,
                      onPressed: onShowDiary,
                      color: const Color(0xFF0D9488), // Teal-600
                      tooltip: 'Toggle diary for selected minion messages',
                      delay: 200,
                    ),
                  ],
                  
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.close,
                    onPressed: onDone,
                    color: const Color(0xFF6B7280), // Gray-500
                    tooltip: 'Exit selection mode',
                    delay: 300,
                  ),
                ],
              ),
            ],
          ),
        ).animate()
          .fadeIn(
            duration: SpringConfig.bouncyDuration,
            curve: SpringConfig.bouncy,
          )
          .moveY(
            begin: -60,
            duration: SpringConfig.bouncyDuration,
            curve: SpringConfig.bouncy,
          )
          .scale(
            begin: const Offset(0.9, 0.9),
            duration: SpringConfig.bouncyDuration,
            curve: SpringConfig.bouncy,
          )
          .vistaShimmer(), // That delicious Vista shimmer
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String tooltip,
    required int delay,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ).animate(delay: Duration(milliseconds: delay))
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .scale(
          begin: const Offset(0.7, 0.7),
          duration: SpringConfig.bouncyDuration,
          curve: SpringConfig.bouncy,
        )
        .animate(target: 0.0) // For press animation
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(0.95, 0.95),
          duration: SpringConfig.stiffDuration,
          curve: SpringConfig.stiff,
        ),
    );
  }
}

/// Compact selection header for mobile or smaller screens
class CompactSelectionHeader extends StatelessWidget {
  final bool isVisible;
  final int selectedCount;
  final bool hasMinions;
  final VoidCallback onDelete;
  final VoidCallback onShowDiary;
  final VoidCallback onDone;

  const CompactSelectionHeader({
    super.key,
    required this.isVisible,
    required this.selectedCount,
    required this.hasMinions,
    required this.onDelete,
    required this.onShowDiary,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return SelectionHeader(
      isVisible: isVisible,
      selectedCount: selectedCount,
      hasMinions: hasMinions,
      onDelete: onDelete,
      onShowDiary: onShowDiary,
      onDone: onDone,
    );
  }
}

/// Bottom selection bar variant
class BottomSelectionBar extends StatelessWidget {
  final bool isVisible;
  final int selectedCount;
  final bool hasMinions;
  final VoidCallback onDelete;
  final VoidCallback onShowDiary;
  final VoidCallback onDone;

  const BottomSelectionBar({
    super.key,
    required this.isVisible,
    required this.selectedCount,
    required this.hasMinions,
    required this.onDelete,
    required this.onShowDiary,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedCount message${selectedCount != 1 ? 's' : ''} selected',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  color: const Color(0xFFEF4444),
                  tooltip: 'Delete selected messages',
                ),
                if (hasMinions)
                  IconButton(
                    onPressed: onShowDiary,
                    icon: const Icon(Icons.book),
                    color: const Color(0xFF0D9488),
                    tooltip: 'Toggle diary for selected minion messages',
                  ),
                IconButton(
                  onPressed: onDone,
                  icon: const Icon(Icons.close),
                  tooltip: 'Exit selection mode',
                ),
              ],
            ),
          ],
        ),
      ).animate()
        .fadeIn(
          duration: SpringConfig.gentleDuration,
          curve: SpringConfig.gentle,
        )
        .moveY(
          begin: 100,
          duration: SpringConfig.slideDuration,
          curve: SpringConfig.slide,
        ),
    );
  }
}