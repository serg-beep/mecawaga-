import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/auth_repository.dart';

class AccountManagementActions extends ConsumerWidget {
  const AccountManagementActions({super.key});

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action est définitive. Vos annonces, motos, interventions, '
              'rappels et accès seront supprimés. Confirmez votre mot de passe '
              'pour continuer.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.erreur,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, passwordController.text),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Suppression de vos données…')),
            ],
          ),
        ),
      ),
    );
    try {
      await ref.read(authServiceProvider).deleteAccount(password: password);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/login');
      }
    } on AuthException catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La suppression n’a pas abouti. Vérifiez votre connexion puis réessayez.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('À propos'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/about'),
      ),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Politique de confidentialité'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/legal/privacy'),
      ),
      ListTile(
        leading: const Icon(Icons.description_outlined),
        title: const Text('Conditions d’utilisation'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/legal/terms'),
      ),
      ListTile(
        leading: const Icon(
          Icons.delete_forever_outlined,
          color: AppColors.erreur,
        ),
        title: const Text(
          'Supprimer mon compte',
          style: TextStyle(color: AppColors.erreur),
        ),
        subtitle: const Text('Suppression définitive de vos données'),
        onTap: () => _deleteAccount(context, ref),
      ),
    ],
  );
}
