import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/marche_providers.dart';
import '../../data/annonce_repository.dart';
import '../../domain/annonce.dart';
import '../../marche_constants.dart';
import '../marche_widgets.dart';

class AnnonceDetailPage extends ConsumerStatefulWidget {
  const AnnonceDetailPage({required this.annonceId, super.key});
  final String annonceId;

  @override
  ConsumerState<AnnonceDetailPage> createState() => _AnnonceDetailPageState();
}

class _AnnonceDetailPageState extends ConsumerState<AnnonceDetailPage> {
  int _photoIndex = 0;
  bool _busy = false;

  void _message(String message, {bool error = false}) {
    afficherConfirmation(context, message, erreur: error);
  }

  Future<void> _contact(Annonce annonce, {required bool whatsapp}) async {
    final phone = annonce.telephone.replaceAll(RegExp(r'\D'), '');
    final number = phone.startsWith('226') ? phone : '226$phone';
    final uri = whatsapp
        ? Uri.https('wa.me', '/$number', {
            'text':
                'Bonjour, je suis intéressé par votre annonce « ${annonce.titre} » sur MecaWaga.',
          })
        : Uri(scheme: 'tel', path: '+$number');
    try {
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          _message(
            whatsapp
                ? 'WhatsApp n’est pas disponible sur cet appareil.'
                : 'Aucune application ne peut passer cet appel.',
            error: true,
          );
        }
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      if (mounted) {
        _message(
          whatsapp
              ? 'Impossible d’ouvrir WhatsApp. Vérifiez que l’application est installée.'
              : 'Impossible d’ouvrir l’application téléphone.',
          error: true,
        );
      }
    } on Exception {
      if (mounted) {
        _message('Le contact est momentanément indisponible.', error: true);
      }
    }
  }

  Future<void> _markSold(Annonce annonce) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marquer comme vendue ?'),
        content: const Text(
          'Cette annonce ne sera plus visible dans le Marché.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Marquer comme vendue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(annonceRepositoryProvider)
          .updateStatus(annonce.id, StatutAnnonce.vendue);
      ref
        ..invalidate(annonceProvider(annonce.id))
        ..invalidate(annoncesActivesProvider)
        ..invalidate(mesAnnoncesProvider(annonce.vendeurId));
      if (mounted) _message('L’annonce est marquée comme vendue.');
    } on Exception {
      if (mounted) {
        _message('Impossible de mettre à jour l’annonce. Réessayez.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(Annonce annonce, String userId) async {
    var selectedReason = motifsSignalement.first;
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Signaler cette annonce',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selectedReason = value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final reason in motifsSignalement)
                        RadioListTile<String>(
                          value: reason,
                          title: Text(reason),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selectedReason),
                  child: const Text('Envoyer le signalement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      final hidden = await ref
          .read(annonceRepositoryProvider)
          .reportAnnouncement(
            Signalement(
              annonceId: annonce.id,
              auteurId: userId,
              motif: reason,
              date: DateTime.now(),
            ),
          );
      ref
        ..invalidate(annonceProvider(annonce.id))
        ..invalidate(annoncesActivesProvider);
      if (mounted) {
        _message(
          hidden
              ? 'Merci. L’annonce a été masquée après plusieurs signalements.'
              : 'Merci, votre signalement a été envoyé.',
        );
      }
    } on MarketRepositoryException catch (error) {
      if (mounted) _message(error.message, error: true);
    } on Exception {
      if (mounted) {
        _message('Impossible d’envoyer le signalement. Réessayez.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcementAsync = ref.watch(annonceProvider(widget.annonceId));
    final user = ref.watch(authServiceProvider).utilisateurConnecte;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonce'),
        actions: [
          if (announcementAsync.valueOrNull case final annonce?
              when user?.id != annonce.vendeurId)
            PopupMenuButton<String>(
              tooltip: 'Autres actions',
              onSelected: (value) {
                if (value == 'report' && user != null) {
                  _report(annonce, user.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Text('Signaler cette annonce'),
                ),
              ],
            ),
        ],
      ),
      body: announcementAsync.when(
        loading: () => const EtatChargement(),
        error: (error, stack) => EtatErreur(
          message: 'Impossible de charger cette annonce. Réessayez.',
          onRetry: () => ref.invalidate(annonceProvider(widget.annonceId)),
        ),
        data: (annonce) {
          if (annonce == null) {
            return const EtatVide(
              icone: Icons.inventory_2_outlined,
              titre: 'Annonce introuvable',
              aide: 'Elle a peut-être été supprimée. Revenez au Marché.',
            );
          }
          final ownListing = user?.id == annonce.vendeurId;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  children: [
                    SizedBox(
                      height: 260,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemCount: annonce.photos.length,
                            onPageChanged: (index) =>
                                setState(() => _photoIndex = index),
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => _AnnoncePhotoViewer(
                                    annonce: annonce,
                                    index: index,
                                  ),
                                ),
                              ),
                              child: Hero(
                                tag: 'annonce-${annonce.id}-$index',
                                child: AnnonceImage(
                                  source: annonce.photos[index],
                                  categorie: annonce.categorie,
                                  cacheWidth: 1200,
                                  cacheHeight: 900,
                                ),
                              ),
                            ),
                          ),
                          if (annonce.photos.length > 1)
                            Positioned(
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                              child: Semantics(
                                label:
                                    'Photo ${_photoIndex + 1} sur ${annonce.photos.length}',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.texte.withValues(
                                      alpha: 0.75,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                  ),
                                  child: Text(
                                    '${_photoIndex + 1} / ${annonce.photos.length}',
                                    style: const TextStyle(
                                      color: AppColors.surface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                formatMarketPrice(annonce.prix),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppColors.bleuFonce,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (annonce.negociable)
                                const Chip(label: Text('Négociable')),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            annonce.titre,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              EtatProduitBadge(etat: annonce.etat),
                              Chip(
                                avatar: Icon(
                                  iconForCategory(annonce.categorie),
                                  size: 18,
                                ),
                                label: Text(annonce.categorie.label),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _InfoLine(
                            icon: Icons.location_on_outlined,
                            text: annonce.localisation,
                          ),
                          _InfoLine(
                            icon: Icons.schedule_outlined,
                            text: formatRelativeDate(
                              annonce.datePublication,
                              DateTime.now(),
                            ),
                          ),
                          if (annonce.champsSpecifiques.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Caractéristiques',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final field
                                in annonce.champsSpecifiques.entries)
                              _InfoLine(
                                icon: Icons.check_circle_outline,
                                text: '${field.key} : ${field.value}',
                              ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            annonce.description,
                            style: const TextStyle(
                              color: AppColors.texte,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.bleuPale,
                                child: Icon(
                                  Icons.person_outline,
                                  color: AppColors.bleu,
                                ),
                              ),
                              title: Text(annonce.vendeurNom),
                              subtitle: annonce.vendeurEstMecanicien
                                  ? const Row(
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: AppColors.bleu,
                                        ),
                                        SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'Mécanicien MecaWaga',
                                          style: TextStyle(
                                            color: AppColors.bleuFonce,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ownListing
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => context.push(
                                        '/market/publish',
                                        extra: annonce,
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Modifier'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _busy ||
                                        annonce.statut != StatutAnnonce.active
                                    ? null
                                    : () => _markSold(annonce),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  foregroundColor: AppColors.texte,
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Marquer comme vendue'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _contact(annonce, whatsapp: false),
                                icon: const Icon(Icons.call_outlined),
                                label: const Text('Appeler'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 52),
                                ),
                              ),
                            ),
                            if (annonce.telephoneWhatsApp) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _contact(annonce, whatsapp: true),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('WhatsApp'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: AppColors.texte,
                                    minimumSize: const Size(48, 52),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.bleu, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.texte))),
      ],
    ),
  );
}

class _AnnoncePhotoViewer extends StatefulWidget {
  const _AnnoncePhotoViewer({required this.annonce, required this.index});
  final Annonce annonce;
  final int index;

  @override
  State<_AnnoncePhotoViewer> createState() => _AnnoncePhotoViewerState();
}

class _AnnoncePhotoViewerState extends State<_AnnoncePhotoViewer> {
  late int _index = widget.index;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.texte,
    appBar: AppBar(
      backgroundColor: AppColors.texte,
      foregroundColor: AppColors.surface,
      title: Text('${_index + 1} / ${widget.annonce.photos.length}'),
    ),
    body: PageView.builder(
      controller: PageController(initialPage: widget.index),
      itemCount: widget.annonce.photos.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (context, index) => Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Hero(
            tag: 'annonce-${widget.annonce.id}-$index',
            child: AnnonceImage(
              source: widget.annonce.photos[index],
              categorie: widget.annonce.categorie,
              fit: BoxFit.contain,
              cacheWidth: 1600,
              cacheHeight: 1600,
            ),
          ),
        ),
      ),
    ),
  );
}
