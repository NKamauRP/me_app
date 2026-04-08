import 'package:flutter/material.dart';

class XPOverlay {
  static void show(BuildContext context, int xp, Color color) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => XPFloater(
        xp: xp,
        color: color,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class XPFloater extends StatefulWidget {
  const XPFloater({
    super.key,
    required this.xp,
    required this.color,
    required this.onDone,
  });

  final int xp;
  final Color color;
  final VoidCallback onDone;

  @override
  State<XPFloater> createState() => _XPFloaterState();
}

class _XPFloaterState extends State<XPFloater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final Animation<double> _offset = Tween<double>(
    begin: 0,
    end: -60,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 62.5),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 37.5),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, _offset.value),
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Text(
                      '+${widget.xp} XP',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
