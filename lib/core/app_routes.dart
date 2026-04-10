import 'package:flutter/material.dart';

Route<T> buildAppRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionDuration: const Duration(milliseconds: 450), // Slower for premium feel
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (
      context,
      animation,
      secondaryAnimation,
      transitionChild,
    ) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart, // Smoother than Cubic
      );
      final scaleAnimation = Tween<double>(
        begin: 0.98,
        end: 1,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            scale: scaleAnimation,
            child: transitionChild,
          ),
        ),
      );
    },
  );
}
