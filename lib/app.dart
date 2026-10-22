import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/firebase/firestore_connectivity.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MecawagaApp extends ConsumerWidget {
  const MecawagaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'MecaWaga',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => ColoredBox(
        color: AppColors.fond,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SizedBox(
                  width: constraints.maxWidth > 600
                      ? 600
                      : constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      child ?? const SizedBox.shrink(),
                      const _OfflineBanner(),
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

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(firestoreOfflineProvider).valueOrNull ?? false;
    if (!offline) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.texte.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            'Hors connexion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
