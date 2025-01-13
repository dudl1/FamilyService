import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

void routing_animations(BuildContext context, String transitionType, Widget toPage) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        height: animation.value * 2,
        child: toPage,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutQuint,
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: transitionType == "vertical" ? SharedAxisTransitionType.vertical : SharedAxisTransitionType.horizontal,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    ),
  );
}