import 'package:flutter/material.dart';

enum InsightState {
  idle,
  loading,
  done,
  error,
}

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.state,
    required this.insightText,
    required this.moodColor,
    required this.onDismiss,
  });

  final InsightState state;
  final String? insightText;
  final Color moodColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (state == InsightState.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final effectiveText = (insightText?.trim().isNotEmpty ?? false)
        ? insightText!.trim()
        : 'Every log is a quiet step toward knowing yourself a little better.';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<String>('${state.name}-$effectiveText'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: moodColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: moodColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: moodColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AI INSIGHT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: moodColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state) {
                InsightState.loading => const TypingDots(),
                _ => Text(
                    effectiveText,
                    key: ValueKey<String>(effectiveText),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      // Using the Serif font from the theme
                      fontFamily: 'Lora',
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  'On-device reasoning · Private',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final activeDot = (_controller.value * 3).floor() % 3;
          return Row(
            children: List.generate(3, (index) {
              final isActive = index == activeDot;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                height: isActive ? 8 : 6,
                width: isActive ? 8 : 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(
                        alpha: isActive ? 1 : 0.35,
                      ),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
