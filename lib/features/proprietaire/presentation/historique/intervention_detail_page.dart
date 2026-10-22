import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/remote_or_local_image.dart';
import '../../domain/intervention.dart';
import '../owner_widgets.dart';

class InterventionDetailPage extends StatelessWidget {
  const InterventionDetailPage({required this.intervention, super.key});

  final Intervention intervention;

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: 'Détail de l’intervention',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          intervention.type.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _DetailRow(
          label: 'Date',
          value: DateFormat('d MMM yyyy', 'fr_FR').format(intervention.date),
        ),
        _DetailRow(
          label: 'Kilométrage',
          value: '${intervention.kilometrage} km',
        ),
        _DetailRow(label: 'Mécanicien', value: intervention.mecanicienNom),
        if (intervention.pieces.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Pièces utilisées',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final piece in intervention.pieces)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.bleu,
              ),
              title: Text(piece),
              minTileHeight: 48,
            ),
        ],
        if (intervention.remarque.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Remarque', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          OwnerCard(
            child: Text(
              intervention.remarque,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
        if (intervention.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Photos et factures',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: intervention.photos.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => Semantics(
                button: true,
                label: 'Afficher la photo ${index + 1} en plein écran',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          _PhotoViewer(path: intervention.photos[index]),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    child: RemoteOrLocalImage(
                      source: intervention.photos[index],
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                      cacheWidth: 224,
                      cacheHeight: 224,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.texteDoux),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.texte,
    appBar: AppBar(
      backgroundColor: AppColors.texte,
      foregroundColor: AppColors.surface,
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: RemoteOrLocalImage(
          source: path,
          cacheWidth: 1024,
          cacheHeight: 1024,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}
