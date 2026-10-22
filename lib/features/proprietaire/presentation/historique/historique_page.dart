import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/intervention.dart';
import '../../domain/moto.dart';
import '../owner_widgets.dart';

final interventionsProvider = StreamProvider.family<List<Intervention>, String>(
  (ref, motoId) => ref
      .watch(proprietaireRepositoryProvider)
      .watchInterventions(motoId),
);

class HistoriquePage extends ConsumerStatefulWidget {
  const HistoriquePage({super.key});

  @override
  ConsumerState<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends ConsumerState<HistoriquePage> {
  TypeIntervention? _filter;

  @override
  Widget build(BuildContext context) {
    final motos = ref.watch(motosProvider);
    final moto = ref.watch(selectedMotoObjectProvider);
    if (motos.isLoading) {
      return const EtatChargement();
    }
    if (motos.hasError) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Historique indisponible',
        message: 'Réessayez pour charger vos motos et leurs interventions.',
        action: FilledButton(
          onPressed: () => ref.invalidate(motosProvider),
          child: const Text('Réessayer'),
        ),
      );
    }
    if (motos.valueOrNull?.isEmpty ?? true) {
      return const StateMessage(
        icon: Icons.two_wheeler_outlined,
        title: 'Ajoutez une moto',
        message:
            'L’historique s’affichera après l’ajout de votre première moto.',
      );
    }
    if (moto == null) return const Center(child: CircularProgressIndicator());
    final interventions = ref.watch(interventionsProvider(moto.id));

    return Column(
      children: [
        if (motos.value!.length > 1)
          MotoSelector(
            motos: motos.value!,
            selected: moto,
            onChanged: (value) =>
                ref.read(selectedMotoProvider.notifier).state = value.id,
          ),
        Expanded(
          child: interventions.when(
            loading: () => const EtatChargement(rows: 4, showHeader: false),
            error: (error, stack) => StateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Impossible de charger l’historique',
              message: 'Vérifiez votre connexion puis réessayez.',
              action: FilledButton(
                onPressed: () => ref.invalidate(interventionsProvider(moto.id)),
                child: const Text('Réessayer'),
              ),
            ),
            data: (items) => _historyList(context, moto, items),
          ),
        ),
      ],
    );
  }

  Widget _historyList(
    BuildContext context,
    Moto moto,
    List<Intervention> items,
  ) {
    final filtered = _filter == null
        ? items
        : items.where((item) => item.type == _filter).toList();
    final header = OwnerCard(
      child: Row(
        children: [
          const Icon(Icons.speed_rounded, color: AppColors.bleu, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moto.nom, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${moto.kilometrage} km · ${items.length} intervention${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Partager l’historique',
            onPressed: () => context.push('/owner/access/${moto.id}'),
            icon: const Icon(Icons.share_outlined, color: AppColors.bleu),
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: timelineCount + 3,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        if (index == 1) return const SizedBox(height: 12);
        if (index == 2) return filters;
        if (filtered.isEmpty) {
          return const StateMessage(
            icon: Icons.history,
            title: 'Aucune intervention',
            message:
                'Les entretiens ajoutés par votre mécanicien apparaîtront ici.',
          );
        }
        final item = filtered[index - 3];
        return ListItemEntrance(
          key: ValueKey('intervention-${item.id}'),
          child: _InterventionTile(item: item),
        );
      },
    );
  }
}

class _InterventionTile extends StatelessWidget {
  const _InterventionTile({required this.item});

  final Intervention item;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy', 'fr_FR').format(item.date);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OwnerCard(
        onTap: () =>
            context.push('/owner/intervention/${item.id}', extra: item),
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
                    '$date · ${item.kilometrage} km',
                    style: const TextStyle(color: AppColors.texteDoux),
                  ),
                  Text(
                    item.mecanicienNom,
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
}
