import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/remote_or_local_image.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/moto.dart';
import '../owner_widgets.dart';

class MotoListPage extends ConsumerWidget {
  const MotoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motos = ref.watch(motosProvider);
    return motos.when(
      loading: () => const EtatChargement(),
      error: (error, stack) => StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Impossible de charger vos motos',
        message: '$error',
        action: FilledButton(
          onPressed: () => ref.invalidate(motosProvider),
          child: const Text('Réessayer'),
        ),
      ),
      data: (items) => items.isEmpty
          ? StateMessage(
              icon: Icons.two_wheeler_outlined,
              title: 'Aucune moto pour le moment',
              message:
                  'Vous n’avez pas encore de moto. Appuyez sur « Ajouter une moto » pour commencer.',
              action: FilledButton.icon(
                onPressed: () => context.push('/owner/moto/form'),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une moto'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                96,
              ),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index < items.length) {
                  return ListItemEntrance(
                    key: ValueKey('moto-${items[index].id}'),
                    child: _MotoCard(moto: items[index]),
                  );
                }
                if (index == items.length) return const SizedBox(height: 8);
                return OutlinedButton.icon(
                  onPressed: () => context.push('/owner/moto/form'),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une moto'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                  ),
                );
              },
            ),
    );
  }
}

class _MotoCard extends ConsumerWidget {
  const _MotoCard({required this.moto});

  final Moto moto;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OwnerCard(
      onTap: () {
        ref.read(selectedMotoProvider.notifier).state = moto.id;
        context.go('/owner?tab=history');
      },
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.bleu.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: moto.photo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    child: RemoteOrLocalImage(
                      source: moto.photo!,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      cacheWidth: 248,
                      cacheHeight: 248,
                    ),
                  )
                : const Icon(
                    Icons.two_wheeler,
                    color: AppColors.bleu,
                    size: 34,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moto.nom, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${moto.immatriculation} · ${formatKm(moto.kilometrage)}',
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
                const SizedBox(height: 4),
                Text(
                  moto.type.label,
                  style: const TextStyle(color: AppColors.bleu),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier ${moto.nom}',
            onPressed: () => context.push('/owner/moto/form', extra: moto),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Rappels proches',
            onPressed: () {
              ref.read(selectedMotoProvider.notifier).state = moto.id;
              context.go('/owner?tab=reminders');
            },
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    ),
  );
}
