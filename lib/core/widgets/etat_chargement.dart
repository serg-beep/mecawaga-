import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EtatChargement extends StatelessWidget {
  const EtatChargement({this.rows = 3, this.showHeader = true, super.key});

  final int rows;
  final bool showHeader;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: [
      if (showHeader) ...[
        _Skeleton(
          width: 180,
          height: 24,
          radius: 8,
          color: AppColors.bordure.withValues(alpha: 0.7),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      for (var index = 0; index < rows; index++) ...[
        const _SkeletonCard(),
        if (index < rows - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.bordure),
    ),
    child: const Row(
      children: [
        _Skeleton(width: 48, height: 48, radius: 24),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Skeleton(width: 170, height: 17, radius: 6),
              SizedBox(height: 9),
              _Skeleton(width: 220, height: 12, radius: 5),
              SizedBox(height: AppSpacing.xs),
              _Skeleton(width: 140, height: 12, radius: 5),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({
    required this.width,
    required this.height,
    this.radius = 10,
    this.color = AppColors.bordure,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
