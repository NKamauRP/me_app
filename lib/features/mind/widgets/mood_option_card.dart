import 'package:flutter/material.dart';

import '../micro_interactions.dart';
import '../mood_catalog.dart';

class MoodOptionCard extends StatelessWidget {
  const MoodOptionCard({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: mood.color.withValues(alpha: isSelected ? 0.28 : 0.12),
            blurRadius: isSelected ? 22 : 12,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: isSelected ? mood.color.withValues(alpha: 0.96) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: TapScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedCheckmark(
                    visible: isSelected,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  mood.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color:
                            isSelected ? Colors.white : const Color(0xFF1D2A28),
                      ),
                ),
                const SizedBox(height: 8),
                Icon(
                  mood.icon,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.92)
                      : mood.color,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
