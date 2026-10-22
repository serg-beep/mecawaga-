import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../../core/widgets/account_management_actions.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/domain/utilisateur.dart';
import '../owner_widgets.dart';

class ProfilProprietairePage extends ConsumerStatefulWidget {
  const ProfilProprietairePage({super.key});

  @override
  ConsumerState<ProfilProprietairePage> createState() =>
      _ProfilProprietairePageState();
}

class _ProfilProprietairePageState
    extends ConsumerState<ProfilProprietairePage> {
  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authServiceProvider).utilisateurConnecte ??
        const Utilisateur(
          nomComplet: 'Alex Martin',
          telephone: '06 12 34 56 78',
          contact: 'demo@mecawaga.fr',
          role: RoleUtilisateur.proprietaire,
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.bleu.withValues(alpha: 0.1),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.bleu,
            size: 40,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            user.nomComplet,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 20),
        OwnerCard(
          child: Column(
            children: [
              _ProfileRow(icon: Icons.person_outline, value: user.nomComplet),
              const Divider(height: 24),
              _ProfileRow(
                icon: Icons.phone_outlined,
                value: user.telephone.isEmpty
                    ? 'Non renseigné'
                    : user.telephone,
              ),
              const Divider(height: 24),
              _ProfileRow(icon: Icons.email_outlined, value: user.contact),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _edit(context, user),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier mon profil'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
        const SizedBox(height: AppSpacing.md),
        const AccountManagementActions(),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push('/market/mine'),
          icon: const Icon(Icons.sell_outlined),
          label: const Text('Mes annonces du Marché'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await confirmerActionIrreversible(
              context,
              titre: 'Se déconnecter ?',
              message:
                  'Vous devrez saisir vos identifiants pour accéder de nouveau à votre compte.',
              confirmation: 'Se déconnecter',
            );
            if (!confirmed || !context.mounted) return;
            ref.read(authServiceProvider).signOut();
            context.go('/login');
          },
          icon: const Icon(Icons.logout, color: AppColors.erreur),
          label: const Text(
            'Se déconnecter',
            style: TextStyle(color: AppColors.erreur),
          ),
          style: TextButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, Utilisateur user) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: user.nomComplet);
    final phone = TextEditingController(text: user.telephone);
    final email = TextEditingController(text: user.contact);
    final messenger = ScaffoldMessenger.of(context);
    bool validFields() {
      return validateName(name.text) == null &&
          validatePhone(phone.text) == null &&
          validateEmail(email.text) == null;
    }

    final updated = await showDialog<Utilisateur>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier mon profil'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  onChanged: (_) => setDialogState(() {}),
                  validator: validateName,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  onChanged: (_) => setDialogState(() {}),
                  validator: validatePhone,
                ),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  validator: validateEmail,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: validFields()
                  ? () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(
                        context,
                        user.copyWith(
                          nomComplet: name.text.trim(),
                          telephone: phone.text.trim(),
                          contact: email.text.trim().toLowerCase(),
                        ),
                      );
                    }
                  : null,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    email.dispose();
    if (updated != null && mounted) {
      ref.read(authServiceProvider).updateProfile(updated);
      setState(() {});
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Votre profil a été mis à jour.')),
        );
    }
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.bleu),
      const SizedBox(width: 12),
      Expanded(child: Text(value)),
    ],
  );
}
