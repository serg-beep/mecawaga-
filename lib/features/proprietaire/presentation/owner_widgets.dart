import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/etat_messages.dart';
import '../domain/moto.dart';

class OwnerPage extends StatelessWidget {
  const OwnerPage({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: child),
  );
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isError =
        icon == Icons.cloud_off_outlined || icon == Icons.error_outline;
    if (isError) {
      return EtatErreur(
        icone: icon,
        titre: title,
        message: message,
        action: action,
      );
    }
    return EtatVide(icone: icon, titre: title, aide: message, action: action);
  }
}

class MotoSelector extends StatelessWidget {
  const MotoSelector({
    required this.motos,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Moto> motos;
  final Moto selected;
  final ValueChanged<Moto> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: DropdownButtonFormField<String>(
      initialValue: selected.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Moto sélectionnée',
        prefixIcon: Icon(Icons.two_wheeler),
      ),
      items: motos
          .map(
            (moto) => DropdownMenuItem(
              value: moto.id,
              child: Text(
                moto.nom,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id == null) return;
        onChanged(motos.firstWhere((moto) => moto.id == id));
      },
    ),
  );
}

class OwnerCard extends StatelessWidget {
  const OwnerCard({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: const BorderSide(color: AppColors.bordure),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    ),
  );
}

String formatKm(int value) => '${value.toString()} km';
