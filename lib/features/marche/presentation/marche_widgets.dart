import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/annonce.dart';
import '../marche_constants.dart';

class AnnonceImage extends StatelessWidget {
  const AnnonceImage({
    required this.source,
    required this.categorie,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
  });

  final String? source;
  final Categorie categorie;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final path = source;
    if (path == null || path.isEmpty) {
      return _fallback();
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (context, url) => _fallback(),
        errorWidget: (context, url, error) => _fallback(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path == photoRemplacementMarche ? path : photoRemplacementMarche,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stack) => _fallback(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  Widget _fallback() => ColoredBox(
    color: AppColors.bleuPale,
    child: Center(
      child: Icon(iconForCategory(categorie), color: AppColors.bleu, size: 44),
    ),
  );
}

class AnnonceCard extends StatelessWidget {
  const AnnonceCard({required this.annonce, required this.onTap, super.key});

  final Annonce annonce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${annonce.titre}, ${formatMarketPrice(annonce.prix)}, ${annonce.localisation}',
    child: Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.bordure),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnnonceImage(
                    source: annonce.photos.firstOrNull,
                    categorie: annonce.categorie,
                    cacheWidth: 360,
                    cacheHeight: 280,
                  ),
                  if (annonce.vendeurEstMecanicien)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: AppColors.bleu,
                              size: 16,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                'Mécanicien MecaWaga',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.texte,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMarketPrice(annonce.prix),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.bleuFonce,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    annonce.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.texte,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.texteDoux,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          annonce.localisation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.texteDoux,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  EtatProduitBadge(etat: annonce.etat),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EtatProduitBadge extends StatelessWidget {
  const EtatProduitBadge({required this.etat, super.key});
  final EtatProduit etat;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: etat == EtatProduit.neuf ? AppColors.bleuPale : AppColors.fond,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_etatIcon(etat), size: 14, color: AppColors.bleuFonce),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            etat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class StatutAnnonceBadge extends StatelessWidget {
  const StatutAnnonceBadge({required this.statut, super.key});
  final StatutAnnonce statut;

  @override
  Widget build(BuildContext context) {
    final (
      String label,
      IconData icon,
      Color foreground,
      Color background,
    ) = switch (statut) {
      StatutAnnonce.active => (
        'En vente',
        Icons.check_circle_outline,
        AppColors.bleuFonce,
        AppColors.bleuPale,
      ),
      StatutAnnonce.vendue => (
        'Vendue',
        Icons.sell_outlined,
        AppColors.texte,
        AppColors.fond,
      ),
      StatutAnnonce.masquee => (
        'Masquée',
        Icons.visibility_off_outlined,
        AppColors.erreur,
        AppColors.erreur.withValues(alpha: 0.08),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

IconData iconForCategory(Categorie categorie) => switch (categorie) {
  Categorie.motosOccasion => Icons.two_wheeler,
  Categorie.moteurs => Icons.settings,
  Categorie.piecesDetachees => Icons.build,
  Categorie.outilsEtCles => Icons.handyman,
  Categorie.accessoires => Icons.motorcycle,
  Categorie.autres => Icons.inventory_2_outlined,
};

IconData _etatIcon(EtatProduit etat) => switch (etat) {
  EtatProduit.neuf => Icons.new_releases_outlined,
  EtatProduit.tresBonEtat => Icons.star_outline,
  EtatProduit.bonEtat => Icons.check_circle_outline,
  EtatProduit.aReparerOuPourPieces => Icons.construction_outlined,
};

String formatMarketPrice(int price) {
  final digits = price.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(' ');
    output.write(digits[index]);
  }
  return '${output.toString()} FCFA';
}

String formatRelativeDate(DateTime date, DateTime now) {
  final age = now.difference(date);
  if (age.inDays <= 0) return 'Publiée aujourd’hui';
  if (age.inDays == 1) return 'Publiée il y a 1 jour';
  if (age.inDays < 30) return 'Publiée il y a ${age.inDays} jours';
  if (age.inDays < 365) return 'Publiée il y a ${age.inDays ~/ 30} mois';
  return 'Publiée il y a ${age.inDays ~/ 365} an(s)';
}
