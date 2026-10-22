import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import '../../data/notification_service.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/moto.dart';
import '../../domain/rappel.dart';
import '../owner_widgets.dart';

class RappelsPage extends ConsumerWidget {
  const RappelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motos = ref.watch(motosProvider);
    final moto = ref.watch(selectedMotoObjectProvider);
    if (motos.isLoading) {
      return const EtatChargement();
    }
    if (motos.hasError) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Rappels indisponibles',
        message: 'Impossible de charger vos motos. Réessayez.',
        action: FilledButton(
          onPressed: () => ref.invalidate(motosProvider),
          child: const Text('Réessayer'),
        ),
      );
    }
    if (moto == null) {
      return const StateMessage(
        icon: Icons.notifications_none,
        title: 'Ajoutez une moto',
        message: 'Vous pourrez créer des rappels après avoir ajouté une moto.',
      );
    }
    final rappels = ref.watch(rappelsProvider(moto.id));
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
          child: rappels.when(
            loading: () => const EtatChargement(rows: 4, showHeader: false),
            error: (error, stack) => StateMessage(
              icon: Icons.error_outline,
              title: 'Erreur de chargement',
              message: 'Réessayez pour afficher vos rappels.',
              action: FilledButton(
                onPressed: () => ref.invalidate(rappelsProvider(moto.id)),
                child: const Text('Réessayer'),
              ),
            ),
            data: (items) => items.isEmpty
                ? StateMessage(
                    icon: Icons.notifications_none,
                    title: 'Aucun rappel prévu',
                    message:
                        'Ajoutez une échéance pour ne pas oublier le prochain entretien.',
                    action: FilledButton.icon(
                      onPressed: () => _showAddDialog(context, ref, moto),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer un rappel'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListItemEntrance(
                        key: ValueKey('rappel-${item.id}'),
                        child: _ReminderTile(
                          rappel: item,
                          onDelete: () => _delete(context, ref, moto, item),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppPrimaryButton(
            label: 'Créer un rappel',
            onPressed: () => _showAddDialog(context, ref, moto),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    Moto moto,
  ) async {
    final selected = await showDialog<Rappel>(
      context: context,
      builder: (dialogContext) => _NewReminderDialog(
        moto: moto,
        onSave: (rappel) async {
          await ref.read(proprietaireRepositoryProvider).saveRappel(rappel);
        },
      ),
    );
    if (!context.mounted) return;
    if (selected == null) return;
    ref.invalidate(rappelsProvider(moto.id));
    var notificationMessage = 'Le rappel a été créé.';
    final wantsNotifications = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Programmer une notification ?'),
        content: const Text(
          'Une alerte locale peut vous prévenir à la date choisie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Pas maintenant'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (wantsNotifications == true) {
      final granted = await PermissionService.instance.request(
        context,
        MecaPermission.notifications,
      );
      if (!context.mounted) return;
      if (!granted) {
        afficherConfirmation(
          context,
          'Le rappel est créé. Vous pouvez activer les notifications dans les réglages.',
        );
        return;
      }
      final now = DateTime.now();
      var scheduledDate = DateTime(
        selected.date.year,
        selected.date.month,
        selected.date.day,
        9,
      );
      if (!scheduledDate.isAfter(now) &&
          selected.date.year == now.year &&
          selected.date.month == now.month &&
          selected.date.day == now.day) {
        scheduledDate = now.add(const Duration(minutes: 1));
      }
      try {
        final scheduled = await NotificationService.instance.scheduleReminder(
          id: selected.notificationId ?? notificationIdFor(selected.id),
          title: selected.titre,
          body: 'Un rappel d’entretien est prévu aujourd’hui pour ${moto.nom}.',
          date: scheduledDate,
        );
        if (!scheduled && context.mounted) {
          notificationMessage =
              'Le rappel est créé, mais sa date est déjà passée et aucune alerte n’a été programmée.';
        }
      } on Exception {
        if (context.mounted) {
          notificationMessage =
              'Le rappel est créé, mais la notification n’a pas pu être programmée. Vérifiez les réglages de l’appareil.';
        }
      }
    }
    if (context.mounted) afficherConfirmation(context, notificationMessage);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Moto moto,
    Rappel rappel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le rappel ?'),
        content: Text('« ${rappel.titre} » sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(proprietaireRepositoryProvider).deleteRappel(rappel.id);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le rappel n’a pas pu être supprimé. Vérifiez votre connexion puis réessayez.',
            ),
          ),
        );
      }
      return;
    }
    ref.invalidate(rappelsProvider(moto.id));
    var message = 'Le rappel a été supprimé.';
    try {
      await NotificationService.instance.cancelReminder(
        rappel.notificationId ?? notificationIdFor(rappel.id),
      );
    } on Exception {
      message =
          'Le rappel a été supprimé, mais son alerte locale n’a pas pu être annulée.';
    }
    if (context.mounted) afficherConfirmation(context, message);
  }
}

class _NewReminderDialog extends StatefulWidget {
  const _NewReminderDialog({required this.moto, required this.onSave});

  final Moto moto;
  final Future<void> Function(Rappel) onSave;

  @override
  State<_NewReminderDialog> createState() => _NewReminderDialogState();
}

class _NewReminderDialogState extends State<_NewReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final reminder = Rappel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      motoId: widget.moto.id,
      titre: _titleController.text.trim(),
      date: _date,
      remarque: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    try {
      await widget.onSave(reminder);
      if (mounted) Navigator.pop(context, reminder);
    } on Exception {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Le rappel n’a pas pu être enregistré. Vérifiez votre connexion puis réessayez ; vos saisies sont conservées.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau rappel'),
    content: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _titleController,
              label: 'Titre du rappel',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Saisissez un titre pour le rappel.'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (value != null) setState(() => _date = value);
                    },
              icon: const Icon(Icons.calendar_month),
              label: Text(DateFormat('d MMM yyyy', 'fr_FR').format(_date)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _noteController,
              label: 'Remarque (facultative)',
              validator: (_) => null,
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.erreur)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enregistrer'),
      ),
    ],
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.rappel, required this.onDelete});
  final Rappel rappel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = rappel.date.difference(DateTime.now()).inDays;
    final label = days <= 0
        ? 'Aujourd’hui'
        : 'Dans $days jour${days == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OwnerCard(
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rappel.titre,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  Text(
                    DateFormat('d MMM yyyy', 'fr_FR').format(rappel.date),
                    style: const TextStyle(color: AppColors.texteDoux),
                  ),
                  if (rappel.remarque != null)
                    Text(
                      rappel.remarque!,
                      style: const TextStyle(color: AppColors.texteDoux),
                    ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.bleu,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer le rappel',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
