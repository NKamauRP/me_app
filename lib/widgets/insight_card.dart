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
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<String>('${state.name}-$effectiveText'),
        decoration: BoxDecoration(
          color: moodColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border(
            left: BorderSide(color: moodColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'AI insight',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state) {
                InsightState.loading => const _TypingDots(),
                InsightState.done || InsightState.error => Text(
                    effectiveText,
                    key: ValueKey<String>(effectiveText),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                InsightState.idle => const SizedBox.shrink(),
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'on device · private',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
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
