import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/marche_providers.dart';
import '../../domain/annonce.dart';
import '../marche_widgets.dart';

class MesAnnoncesPage extends ConsumerWidget {
  const MesAnnoncesPage({super.key});

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Annonce annonce,
    StatutAnnonce status,
    String userId,
  ) async {
    try {
      await ref.read(annonceRepositoryProvider).updateStatus(annonce.id, status);
      ref
        ..invalidate(mesAnnoncesProvider(userId))
        ..invalidate(annoncesActivesProvider)
        ..invalidate(annonceProvider(annonce.id));
      if (context.mounted) {
        afficherConfirmation(
          context,
          status == StatutAnnonce.vendue
              ? 'L’annonce est marquée comme vendue.'
              : 'L’annonce est de nouveau en vente.',
        );
      }
    } on Exception {
      if (context.mounted) {
        afficherConfirmation(
          context,
          'Impossible de mettre à jour l’annonce. Vérifiez votre connexion et réessayez.',
          erreur: true,
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Annonce annonce,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(annonceRepositoryProvider).deleteAnnouncement(annonce.id);
      ref
        ..invalidate(mesAnnoncesProvider(userId))
        ..invalidate(annoncesActivesProvider)
        ..invalidate(annonceProvider(annonce.id));
      if (context.mounted) afficherConfirmation(context, 'L’annonce a été supprimée.');
    } on Exception {
      if (context.mounted) {
        afficherConfirmation(
          context,
          'Impossible de supprimer l’annonce. Réessayez.',
          erreur: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).utilisateurConnecte;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes annonces')),
        body: const EtatErreur(
          message: 'Reconnectez-vous pour consulter vos annonces.',
        ),
      );
    }
    final announcements = ref.watch(mesAnnoncesProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes annonces'),
        leading: IconButton(
          tooltip: 'Retour au Marché',
          onPressed: () => context.go('/market'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: announcements.when(
        loading: () => const EtatChargement(),
        error: (error, stack) => EtatErreur(
          message:
              'Vérifiez votre connexion puis réessayez de charger vos annonces.',
          onRetry: () => ref.invalidate(mesAnnoncesProvider(user.id)),
        ),
        data: (items) => items.isEmpty
            ? EtatVide(
                icone: Icons.sell_outlined,
                titre: 'Vous n’avez pas encore publié d’annonce',
                aide: 'Publiez un article pour le proposer aux utilisateurs.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/market/publish'),
                  icon: const Icon(Icons.add),
                  label: const Text('Publier une annonce'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final announcement = items[index];
                  return Padding(
                    key: ValueKey(announcement.id),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        side: const BorderSide(color: AppColors.bordure),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => context.push(
                                '/market/annonce/${announcement.id}',
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.field,
                                    ),
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: AnnonceImage(
                                        source: announcement.photos.firstOrNull,
                                        categorie: announcement.categorie,
                                        cacheWidth: 160,
                                        cacheHeight: 160,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          announcement.titre,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.texte,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          formatMarketPrice(announcement.prix),
                                          style: const TextStyle(
                                            color: AppColors.bleuFonce,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        StatutAnnonceBadge(
                                          statut: announcement.statut,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: AppSpacing.xxl),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => context.push(
                                    '/market/publish',
                                    extra: announcement,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Modifier'),
                                ),
                                if (announcement.statut ==
                                    StatutAnnonce.active)
                                  TextButton.icon(
                                    onPressed: () => _changeStatus(
                                      context,
                                      ref,
                                      announcement,
                                      StatutAnnonce.vendue,
                                      user.id,
                                    ),
                                    icon: const Icon(Icons.sell_outlined),
                                    label: const Text('Marquer vendue'),
                                  ),
                                if (announcement.statut !=
                                    StatutAnnonce.active)
                                  TextButton.icon(
                                    onPressed: () => _changeStatus(
                                      context,
                                      ref,
                                      announcement,
                                      StatutAnnonce.active,
                                      user.id,
                                    ),
                                    icon: const Icon(Icons.replay_outlined),
                                    label: const Text('Remettre en vente'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _delete(
                                    context,
                                    ref,
                                    announcement,
                                    user.id,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.erreur,
                                  ),
                                  label: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: AppColors.erreur),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: itemsAreLoadedEmpty(announcements)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/market/publish'),
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.texte,
              icon: const Icon(Icons.add),
              label: const Text('Publier'),
            ),
    );
  }

  bool itemsAreLoadedEmpty(AsyncValue<List<Annonce>> announcements) =>
      announcements.valueOrNull?.isEmpty ?? true;
}
