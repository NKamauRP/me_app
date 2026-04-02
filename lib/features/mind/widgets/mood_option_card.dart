import 'package:flutter/material.dart';

import '../../../core/services/sound_service.dart';
import '../../../shared/widgets/glass_panel.dart';
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: TapScale(
          onTap: () {
            MindHaptics.cardTap();
            SoundService.instance.playTap();
            onTap();
          },
          child: GlassPanel(
            padding: const EdgeInsets.all(16),
            tint: isSelected
                ? mood.color.withValues(alpha: 0.74)
                : mood.color.withValues(alpha: 0.12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedCheckmark(
                    visible: isSelected,
                    color: isSelected ? Colors.white : mood.color,
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
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
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
