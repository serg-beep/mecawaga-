import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/account_management_actions.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../data/mecanicien_providers.dart';

class ProfilMecanicienPage extends ConsumerStatefulWidget {
  const ProfilMecanicienPage({super.key});

  @override
  ConsumerState<ProfilMecanicienPage> createState() =>
      _ProfilMecanicienPageState();
}

class _ProfilMecanicienPageState extends ConsumerState<ProfilMecanicienPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).utilisateurConnecte;
    _nameController.text = user?.nomComplet ?? '';
    _phoneController.text = user?.telephone ?? '';
    _emailController.text = user?.contact ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final auth = ref.read(authServiceProvider);
    final user = auth.utilisateurConnecte;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnectez-vous pour modifier votre profil.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final updated = user.copyWith(
      nomComplet: _nameController.text.trim(),
      telephone: _phoneController.text.trim(),
      contact: _emailController.text.trim(),
    );
    final id = ref.read(mecanicienIdProvider);
    final profile = ref
        .read(mecanicienProfilProvider)
        .copyWith(telephone: updated.telephone);
    try {
      await ref.read(mecanicienRepositoryProvider).saveWorkshopProfile(profile);
      if (!mounted) return;
      auth.updateProfile(updated);
      ref.read(mecanicienProfilOverrideProvider(id).notifier).state = profile;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre profil a été mis à jour.')),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de mettre à jour le profil : $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).utilisateurConnecte;
    final workshop = ref.watch(mecanicienProfilProvider);
    if (user == null) {
      return const StateMessage(
        icon: Icons.person_off_outlined,
        title: 'Profil indisponible',
        message: 'Reconnectez-vous pour afficher les informations du compte.',
      );
    }
    if (!_editing) {
      _nameController.text = user.nomComplet;
      _phoneController.text = user.telephone;
      _emailController.text = user.contact;
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        OwnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workshop.nomAtelier,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _profileLine(Icons.person_outline, user.nomComplet),
              _profileLine(Icons.phone_outlined, user.telephone),
              _profileLine(Icons.email_outlined, user.contact),
              const SizedBox(height: 12),
              if (!_editing)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier mon profil'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 50),
                  ),
                )
              else
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: validateName,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: validatePhone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editing = false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 50),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 50),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Enregistrer'),
                            ),
                          ),
                        ],
                      ),
                      if (!_editing) ...[
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/market/mine'),
                          icon: const Icon(Icons.sell_outlined),
                          label: const Text('Mes annonces du Marché'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 52),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Aperçu de votre atelier',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Voici comment les propriétaires voient votre atelier.',
          style: TextStyle(color: AppColors.texteDoux, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () =>
                context.push('/mechanic/profile/preview', extra: workshop),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Voir l’aperçu public'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AccountManagementActions(),
      ],
    );
  }

  Widget _profileLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.bleu),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text.isEmpty ? 'Non renseigné' : text)),
      ],
    ),
  );
}
