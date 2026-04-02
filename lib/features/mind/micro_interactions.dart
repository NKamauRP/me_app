import 'package:flutter/material.dart';

import '../../core/services/haptics_service.dart';

class MindHaptics {
  static Future<void> cardTap() => HapticsService.instance.lightImpact();

  static Future<void> sliderTick() => HapticsService.instance.mediumImpact();

  static Future<void> confirm() => HapticsService.instance.heavyImpact();

  static Future<void> celebrate() => HapticsService.instance.heavyImpact();
}

class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scaleDown = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scaleDown;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    if (!widget.enabled) {
      return;
    }

    setState(() => _scale = pressed ? widget.scaleDown : 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.enabled ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class AnimatedCheckmark extends StatelessWidget {
  const AnimatedCheckmark({
    super.key,
    required this.visible,
    this.color = Colors.white,
  });

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: visible ? 1 : 0.6,
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(Icons.check_rounded, size: 18, color: color),
        ),
      ),
    );
  }
}

class RevealOnBuild extends StatefulWidget {
  const RevealOnBuild({
    super.key,
    required this.child,
    this.offset = const Offset(0, 18),
    this.duration = const Duration(milliseconds: 450),
    this.onCompleted,
  });

  final Widget child;
  final Offset offset;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<RevealOnBuild> createState() => _RevealOnBuildState();
}

class _RevealOnBuildState extends State<RevealOnBuild>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: Offset(widget.offset.dx / 100, widget.offset.dy / 100),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward().whenComplete(() => widget.onCompleted?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class AnimatedActionButton extends StatelessWidget {
  const AnimatedActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return TapScale(
      enabled: enabled,
      onTap: () {
        MindHaptics.confirm();
        onPressed?.call();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1D7A72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
