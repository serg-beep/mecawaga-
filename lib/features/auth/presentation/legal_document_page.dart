import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum LegalDocument { privacy, terms }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = document == LegalDocument.privacy;
    final sections = isPrivacy ? _privacySections : _termsSections;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPrivacy ? 'Politique de confidentialité' : 'Conditions d’utilisation',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Document à valider avant la mise en production. Faites relire '
                'ces informations par un professionnel du droit et complétez '
                'les coordonnées de l’éditeur et du responsable des données.',
                style: TextStyle(
                  color: AppColors.texte,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final section in sections) ...[
            Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.$2,
              style: const TextStyle(color: AppColors.texte, height: 1.55),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

const _privacySections = <(String, String)>[
  (
    'Données traitées',
    'MecaWaga traite les informations de compte (nom, e-mail, téléphone et '
        'rôle), les informations sur les motos et leur entretien, les profils '
        'd’ateliers, ainsi que les annonces, photos et signalements du Marché. '
        'La position n’est demandée que pour les fonctions qui en ont besoin.',
  ),
  (
    'Utilisation et partage',
    'Ces données servent à fournir les fonctions de l’application. Les '
        'annonces et profils d’ateliers publiés sont visibles par les '
        'utilisateurs connectés. Les coordonnées d’une annonce peuvent être '
        'utilisées pour contacter directement son vendeur par téléphone ou '
        'WhatsApp. Firebase fournit l’authentification, la base de données et '
        'le stockage des photos.',
  ),
  (
    'Conservation et suppression',
    'Vous pouvez demander la suppression du compte depuis votre profil. '
        'L’application supprime les données de compte, annonces, motos, '
        'interventions, rappels, accès et photos qu’elle peut rattacher à ce '
        'compte. Les obligations légales de conservation et les délais doivent '
        'être précisés par l’éditeur avant publication.',
  ),
  (
    'Contact et responsable',
    'À compléter avant publication : identité et coordonnées de l’éditeur, '
        'responsable du traitement, adresse de contact, durée de conservation '
        'et modalités d’exercice des droits.',
  ),
];

const _termsSections = <(String, String)>[
  (
    'Utilisation du service',
    'Vous devez fournir des informations exactes, protéger vos identifiants '
        'et n’utiliser MecaWaga que pour des activités conformes à la loi. '
        'L’accès peut être suspendu en cas d’utilisation abusive.',
  ),
  (
    'Annonces et contacts',
    'Le vendeur est responsable du contenu, du prix, de l’état et des photos '
        'de son annonce. Les utilisateurs organisent directement leurs '
        'échanges par téléphone ou WhatsApp. Aucun paiement ni service de '
        'transaction n’est proposé dans l’application.',
  ),
  (
    'Contenus interdits',
    'Il est interdit de publier des contenus frauduleux, des informations '
        'trompeuses, des produits interdits ou des contenus portant atteinte '
        'aux droits d’autrui. Une annonce peut être masquée par son vendeur '
        'ou retirée par l’administration.',
  ),
  (
    'Limites et contact',
    'MecaWaga ne garantit pas la qualité des biens, la disponibilité des '
        'vendeurs ni la réalisation d’une transaction. Complétez les '
        'coordonnées de l’éditeur, la juridiction applicable et les modalités '
        'de réclamation avant la mise en production.',
  ),
];
