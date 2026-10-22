import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/etat_messages.dart';
import '../auth/data/auth_providers.dart';
import '../auth/domain/utilisateur.dart';

class HomePage extends ConsumerWidget {
  const HomePage({required this.role, super.key});

  final RoleUtilisateur role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMechanic = role == RoleUtilisateur.mecanicien;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MecaWaga'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () async {
              final confirmed = await confirmerActionIrreversible(
                context,
                titre: 'Se déconnecter ?',
                message:
                    'Vous devrez saisir vos identifiants pour accéder de nouveau à votre compte.',
                confirmation: 'Se déconnecter',
              );
              if (!confirmed || !context.mounted) return;
              ref.read(authServiceProvider).signOut();
              context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _WelcomeHeader(isMechanic: isMechanic),
            const SizedBox(height: 24),
            if (isMechanic) ...[_WorkshopNotice(), const SizedBox(height: 24)],
            Text(
              isMechanic ? 'Espace mécanicien' : 'Historique',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isMechanic
                  ? 'Votre espace atelier est prêt à être complété.'
                  : 'Retrouvez ici le suivi d’entretien de votre moto.',
              style: const TextStyle(color: AppColors.texteDoux, height: 1.5),
            ),
            if (!isMechanic) ...[
              const SizedBox(height: 24),
              const _MaintenanceCard(),
            ] else ...[
              const SizedBox(height: 24),
              const _PlaceholderCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.isMechanic});

  final bool isMechanic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: Image.asset(
            'assets/images/logo.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            cacheWidth: 112,
            cacheHeight: 112,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bleu.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: AppColors.bleu,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenue sur MecaWaga',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                isMechanic ? 'Votre espace atelier' : 'Votre espace moto',
                style: const TextStyle(color: AppColors.texteDoux),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkshopNotice extends StatelessWidget {
  const _WorkshopNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangePale,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.55)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.bleuFonce),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Complétez votre atelier pour apparaître dans les recherches',
              style: TextStyle(
                color: AppColors.texte,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bleu,
        borderRadius: BorderRadius.circular(AppRadii.largeCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Prochain entretien',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Text(
                  'dans 36 jours',
                  style: TextStyle(
                    color: AppColors.texte,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Suivez la prochaine échéance d’entretien de votre moto.',
            style: TextStyle(color: AppColors.surface, height: 1.45),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 0.68),
            duration: AppTheme.animationDuration,
            builder: (context, progress, child) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.superpositionClaire,
                color: AppColors.orange,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Progression du suivi',
            style: TextStyle(color: AppColors.surface, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.bordure),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.build_circle_outlined, color: AppColors.bleu, size: 32),
            SizedBox(height: 12),
            Text(
              'Bienvenue dans votre espace',
              style: TextStyle(
                color: AppColors.texte,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Cet écran d’accueil provisoire sera enrichi dans la prochaine phase.',
              style: TextStyle(color: AppColors.texteDoux, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
