import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EtatVide extends StatelessWidget {
  const EtatVide({
    required this.icone,
    required this.titre,
    required this.aide,
    this.action,
    super.key,
  });

  final IconData icone;
  final String titre;
  final String aide;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _EtatMessage(icone: icone, titre: titre, message: aide, action: action);
}

class EtatErreur extends StatelessWidget {
  const EtatErreur({
    required this.message,
    this.titre = 'Impossible de charger les informations',
    this.icone = Icons.cloud_off_outlined,
    this.action,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    super.key,
  });

  final String message;
  final String titre;
  final IconData icone;
  final Widget? action;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => _EtatMessage(
    icone: icone,
    titre: titre,
    message: message,
    action:
        action ??
        (onRetry == null
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              )),
  );
}

Future<bool> confirmerActionIrreversible(
  BuildContext context, {
  required String titre,
  required String message,
  required String confirmation,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmation),
          ),
        ],
      ),
    ) ??
    false;

void afficherConfirmation(
  BuildContext context,
  String message, {
  bool erreur = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.erreur : AppColors.bleuFonce,
      ),
    );
}

class _EtatMessage extends StatelessWidget {
  const _EtatMessage({
    required this.icone,
    required this.titre,
    required this.message,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: AppColors.bleu),
          const SizedBox(height: 16),
          Text(titre, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.texteDoux, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
