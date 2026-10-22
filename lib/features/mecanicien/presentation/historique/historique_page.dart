import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import '../../../proprietaire/domain/intervention.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../data/mecanicien_providers.dart';
import '../../domain/moto_client.dart';

class HistoriqueMecanicienPage extends ConsumerStatefulWidget {
  const HistoriqueMecanicienPage({required this.motoId, super.key});

  final String motoId;

  @override
  ConsumerState<HistoriqueMecanicienPage> createState() =>
      _HistoriqueMecanicienPageState();
}

class _HistoriqueMecanicienPageState
    extends ConsumerState<HistoriqueMecanicienPage> {
  TypeIntervention? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(mecanicienHistoriqueProvider(widget.motoId));
    return OwnerPage(
      title: 'Historique de la moto',
      child: history.when(
        loading: () => const EtatChargement(rows: 4),
        error: (error, stack) => StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Historique indisponible',
          message:
              'Impossible de charger cet historique. Vérifiez votre connexion puis réessayez.',
          action: FilledButton(
            onPressed: () =>
                ref.invalidate(mecanicienHistoriqueProvider(widget.motoId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (value) => value == null
            ? const AccessRemovedPage()
            : _historyContent(context, value),
      ),
    );
  }

  Widget _historyContent(BuildContext context, HistoriqueMecanicien history) {
    final filtered = _filter == null
        ? history.interventions
        : history.interventions.where((item) => item.type == _filter).toList();
    final header = OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            history.client.moto.nom,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            history.client.moto.immatriculation,
            style: const TextStyle(
              color: AppColors.texteDoux,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Kilométrage',
            style: TextStyle(color: AppColors.texteDoux),
          ),
          const SizedBox(height: AppSpacing.xs),
          _MileageCounter(value: history.client.moto.kilometrage),
          const SizedBox(height: 12),
          Text(
            '${history.interventions.length} intervention${history.interventions.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.bleuFonce,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Tout'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
          ),
          for (final type in TypeIntervention.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(type.label),
                selected: _filter == type,
                onSelected: (_) =>
                    setState(() => _filter = _filter == type ? null : type),
              ),
            ),
        ],
      ),
    );
    final timelineCount = filtered.isEmpty ? 1 : filtered.length;
    final spacerIndex = 3 + timelineCount;
    final buttonIndex = spacerIndex + 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: buttonIndex + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        if (index == 1) return const SizedBox(height: 12);
        if (index == 2) return filters;
        if (index < spacerIndex) {
          if (filtered.isEmpty) {
            return const StateMessage(
              icon: Icons.history,
              title: 'Aucune intervention',
              message:
                  'Les interventions disponibles pour cette moto apparaîtront ici.',
            );
          }
          final intervention = filtered[index - 3];
          return ListItemEntrance(
            key: ValueKey('intervention-${intervention.id}'),
            child: _InterventionTile(item: intervention, motoId: widget.motoId),
          );
        }
        if (index == spacerIndex) return const SizedBox(height: AppSpacing.md);
        return SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () async {
              final saved = await context.push<bool>(
                '/mechanic/add-intervention/${widget.motoId}',
              );
              if (!context.mounted || saved != true) return;
              ref.invalidate(mecanicienHistoriqueProvider(widget.motoId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('L’intervention a été ajoutée à l’historique.'),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une intervention'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.texte,
            ),
          ),
        );
      },
    );
  }
}

class _MileageCounter extends StatelessWidget {
  const _MileageCounter({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: AppTheme.animationDuration,
      builder: (context, current, child) {
        final digits = current.toString().split('');
        return Wrap(
          spacing: 4,
          children: [
            for (final digit in digits)
              Container(
                constraints: const BoxConstraints(minWidth: 26, minHeight: 34),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.fond,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  border: Border.all(color: AppColors.bordure),
                ),
                child: Text(
                  digit,
                  style: const TextStyle(
                    color: AppColors.bleuFonce,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(left: 3, top: 8),
              child: Text('km', style: TextStyle(color: AppColors.texteDoux)),
            ),
          ],
        );
      },
    );
  }
}

class _InterventionTile extends StatelessWidget {
  const _InterventionTile({required this.item, required this.motoId});

  final Intervention item;
  final String motoId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OwnerCard(
      onTap: () =>
          context.push('/mechanic/moto/$motoId/intervention/${item.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bleu.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.build_outlined, color: AppColors.bleu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('d MMM yyyy', 'fr_FR').format(item.date)} · ${item.kilometrage} km',
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class AccessRemovedPage extends StatelessWidget {
  const AccessRemovedPage({super.key});

  @override
  Widget build(BuildContext context) => StateMessage(
    icon: Icons.lock_outline,
    title: 'Accès retiré',
    message:
        'Le propriétaire a retiré votre accès à cette moto. Elle n’est plus disponible dans votre liste de clients.',
    action: FilledButton(
      onPressed: () => context.go('/mechanic'),
      child: const Text('Retour à mes clients'),
    ),
  );
}
