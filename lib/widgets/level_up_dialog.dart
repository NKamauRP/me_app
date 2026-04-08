import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

Future<void> showLevelUpDialog(BuildContext context, int newLevel) {
  return showDialog<void>(
    context: context,
    builder: (_) => LevelUpDialog(level: newLevel),
  );
}

class LevelUpDialog extends StatefulWidget {
  const LevelUpDialog({
    super.key,
    required this.level,
  });

  final int level;

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> {
  late final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(milliseconds: 1600),
  )..play();

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.level}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Level ${widget.level} reached!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep logging to level up further',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Nice!'),
                ),
              ],
            ),
          ),
          Positioned(
            top: -12,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                emissionFrequency: 0.08,
                numberOfParticles: 24,
                shouldLoop: false,
                gravity: 0.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
