import 'package:flutter/material.dart';

export '../../../core/validators/app_validators.dart';

import '../../../core/theme/app_theme.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack
          ? AppBar(
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              backgroundColor: AppColors.transparent,
            )
          : null,
      body: SafeArea(
        top: !showBack,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 52).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.texteDoux,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: Image.asset(
              'assets/images/logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              cacheWidth: 104,
              cacheHeight: 104,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.two_wheeler_rounded,
                color: AppColors.bleu,
                size: 40,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'MecaWaga',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.bleu),
          ),
        ],
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.erreur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.erreur.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.erreur, height: 1.4),
      ),
    );
  }
}

Widget authLink(
  BuildContext context, {
  required String text,
  required VoidCallback onPressed,
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.bleu,
    ),
    child: Text(text, textAlign: TextAlign.center),
  );
}
