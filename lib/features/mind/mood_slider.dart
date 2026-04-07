import 'package:flutter/material.dart';

import '../../shared/widgets/glass_panel.dart';
import 'micro_interactions.dart';

class MoodIntensitySlider extends StatefulWidget {
  const MoodIntensitySlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  State<MoodIntensitySlider> createState() => _MoodIntensitySliderState();
}

class _MoodIntensitySliderState extends State<MoodIntensitySlider> {
  late double _sliderValue;
  late int _lastHapticValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.value.toDouble();
    _lastHapticValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant MoodIntensitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _sliderValue = widget.value.toDouble();
      _lastHapticValue = widget.value;
    }
  }

  String get _label {
    final rounded = _sliderValue.round();
    if (rounded <= 3) {
      return 'Light';
    }
    if (rounded <= 7) {
      return 'Noticeable';
    }
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        tint: widget.color.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mood intensity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'How strongly are you feeling this right now?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '1',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: widget.color,
                      inactiveTrackColor: widget.color.withValues(alpha: 0.16),
                      thumbColor: widget.color,
                      overlayColor: widget.color.withValues(alpha: 0.16),
                      trackHeight: 8,
                    ),
                    child: Slider(
                      min: 1,
                      max: 10,
                      divisions: 9,
                      value: _sliderValue,
                      label: _sliderValue.round().toString(),
                      onChanged: (value) {
                        final rounded = value.round();
                        final shouldPulse = rounded != _lastHapticValue &&
                            (rounded == 1 || rounded == 5 || rounded == 10);
                        if (shouldPulse) {
                          MindHaptics.sliderTick();
                        }
                        _lastHapticValue = rounded;

                        setState(() => _sliderValue = value);
                        widget.onChanged(rounded);
                      },
                    ),
                  ),
                ),
                Text(
                  '10',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Row(
                key: ValueKey<int>(_sliderValue.round()),
                children: [
                  Text(
                    '${_sliderValue.round()}/10',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: widget.color,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
