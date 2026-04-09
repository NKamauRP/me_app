import 'package:flutter/material.dart';

import '../../../core/services/feedback_service.dart';
import '../micro_interactions.dart';
import '../mood_catalog.dart';

class MoodOptionCard extends StatefulWidget {
  const MoodOptionCard({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
    this.isWide = false,
  });

  final MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isWide;

  @override
  State<MoodOptionCard> createState() => _MoodOptionCardState();
}

class _MoodOptionCardState extends State<MoodOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _emojiScale;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _emojiScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 0.97)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.97, end: 1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant MoodOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    FeedbackService.instance.moodTap();
    _bounceController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = !widget.isWide && width < 400;
    final emojiSize = isCompact ? 26.0 : 30.0;
    final labelFontSize = isCompact ? 13.5 : 15.0;
    final verticalPadding = widget.isWide ? 16.0 : (isCompact ? 8.0 : 12.0);
    final horizontalPadding = widget.isWide ? 18.0 : (isCompact ? 8.0 : 10.0);
    final labelSpacing = isCompact ? 6.0 : 10.0;
    final checkmarkSpacing = isCompact ? 4.0 : 6.0;
    final selectedBorder = widget.mood.color;
    final neutralBorder = const Color(0xFFD9D9D9);
    final background = widget.isSelected
        ? widget.mood.color.withValues(alpha: 0.18)
        : widget.mood.isCustom
            ? const Color(0xFFF7F7F7)
            : widget.mood.color.withValues(alpha: 0.12);

    return Semantics(
      label: widget.mood.label,
      button: true,
      selected: widget.isSelected,
      toggled: widget.isSelected,
      child: TapScale(
        scaleDown: 0.985,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isSelected ? selectedBorder : neutralBorder,
              width: widget.isSelected ? 2.2 : 1.2,
            ),
          ),
          child: widget.isWide
              ? Row(
                  children: [
                    AnimatedBuilder(
                      animation: _emojiScale,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _emojiScale.value,
                          child: Text(
                            widget.mood.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.mood.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    AnimatedCheckmark(
                      visible: widget.isSelected,
                      color: widget.mood.color,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _emojiScale,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _emojiScale.value,
                          child: Text(
                            widget.mood.emoji,
                            style: TextStyle(fontSize: emojiSize),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: labelSpacing),
                    Flexible(
                      child: Text(
                        widget.mood.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: labelFontSize,
                              height: 1.12,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: checkmarkSpacing),
                    AnimatedCheckmark(
                      visible: widget.isSelected,
                      color: widget.mood.color,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
