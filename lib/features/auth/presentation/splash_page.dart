import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_providers.dart';
import '../domain/utilisateur.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_continue());
  }

  Future<void> _continue() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final user = ref.read(authServiceProvider).utilisateurConnecte;
    if (user == null) {
      context.go('/login');
    } else {
      context.go('/home/${user.role.routeSegment}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(
                Radius.circular(AppRadii.largeCard),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 104,
                height: 104,
                fit: BoxFit.contain,
                cacheWidth: 208,
                cacheHeight: 208,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.two_wheeler_rounded,
                  size: 64,
                  color: AppColors.bleu,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'MecaWaga',
              style: const TextStyle(
                color: AppColors.bleu,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
