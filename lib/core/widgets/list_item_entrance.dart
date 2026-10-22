import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ListItemEntrance extends StatelessWidget {
  const ListItemEntrance({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppTheme.animationDuration,
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, opacity, child) => Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - opacity)),
        child: child,
      ),
    ),
  );
}
