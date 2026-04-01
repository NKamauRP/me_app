import 'dart:async';

import 'package:flutter/material.dart';

import 'micro_interactions.dart';

class ReflectionPromptCard extends StatelessWidget {
  const ReflectionPromptCard({
    super.key,
    required this.prompt,
    required this.intensity,
    required this.color,
    required this.textController,
  });

  final String prompt;
  final int intensity;
  final Color color;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return RevealOnBuild(
      offset: const Offset(0, 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Intensity $intensity/10',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                prompt,
                key: ValueKey<String>(prompt),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Take one honest breath and write what is true right now.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 18),
            _AnimatedHintTextField(
              controller: textController,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHintTextField extends StatefulWidget {
  const _AnimatedHintTextField({
    required this.controller,
    required this.color,
  });

  final TextEditingController controller;
  final Color color;

  @override
  State<_AnimatedHintTextField> createState() => _AnimatedHintTextFieldState();
}

class _AnimatedHintTextFieldState extends State<_AnimatedHintTextField> {
  static const List<String> _hints = <String>[
    'A few honest words are enough...',
    'What stands out most right now?',
    'Name the moment without editing it...',
  ];

  Timer? _timer;
  int _hintIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
    _timer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted || widget.controller.text.isNotEmpty) {
        return;
      }

      // Rotating a short set of hints makes the empty state feel alive
      // without distracting once the user starts typing.
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedHintTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        TextField(
          controller: widget.controller,
          minLines: 6,
          maxLines: 8,
          maxLength: 240,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '',
          ),
        ),
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: widget.controller.text.isEmpty ? 1 : 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  _hints[_hintIndex],
                  key: ValueKey<int>(_hintIndex),
                  style: TextStyle(
                    color: widget.color.withValues(alpha: 0.58),
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
