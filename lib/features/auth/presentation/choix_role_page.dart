import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/utilisateur.dart';
import 'auth_components.dart';

class ChoixRolePage extends StatelessWidget {
  const ChoixRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Quel est votre profil ?',
      subtitle: 'Choisissez le profil qui correspond à votre activité.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            icon: Icons.person_outline_rounded,
            title: 'Propriétaire',
            description: 'Suivez l’entretien et l’historique de votre moto.',
            onTap: () => context.go(
              '/register/${RoleUtilisateur.proprietaire.routeSegment}',
            ),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.build_outlined,
            title: 'Mécanicien',
            description: 'Présentez votre atelier et vos spécialités.',
            onTap: () => context.go(
              '/register/${RoleUtilisateur.mecanicien.routeSegment}',
            ),
          ),
          const SizedBox(height: 20),
          authLink(
            context,
            text: 'J’ai déjà un compte : me connecter',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.bordure),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.bleu.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(icon, color: AppColors.bleu, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.texteDoux,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.bleu),
            ],
          ),
        ),
      ),
    );
  }
}
