import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/utilisateur.dart';
import 'auth_components.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({required this.role, super.key});

  final RoleUtilisateur role;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static const _typesMoto = ['Moto 125 cc', 'Scooter', 'Moto sport', 'Trail'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _atelier = TextEditingController();
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final Set<String> _selectedTypes = {};
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _loading = false;
  String? _submitError;

  bool get _isMechanic => widget.role == RoleUtilisateur.mecanicien;
  bool get _valid {
    final name = validateName(_name.text) == null;
    final phone = validatePhone(_phone.text) == null;
    final email = validateEmail(_email.text) == null;
    final password = validatePassword(_password.text) == null;
    final confirmation =
        _confirmation.text == _password.text && _confirmation.text.isNotEmpty;
    final mechanicFields =
        !_isMechanic ||
        (_atelier.text.trim().isNotEmpty && _selectedTypes.isNotEmpty);
    return name &&
        phone &&
        email &&
        password &&
        confirmation &&
        _acceptedTerms &&
        mechanicFields;
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _name,
      _phone,
      _email,
      _password,
      _confirmation,
      _atelier,
    ]) {
      controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() => _submitError = null);
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre mot de passe.';
    }
    if (value != _password.text) {
      return 'Les mots de passe ne correspondent pas. Vérifiez les deux champs.';
    }
    return null;
  }

  String? _validateWorkshop(String? value) {
    if (_isMechanic && validateName(value) != null) {
      return 'Saisissez le nom de votre atelier.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || (_isMechanic && _selectedTypes.isEmpty)) {
      setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _submitError = null;
    });
    final user = Utilisateur(
      nomComplet: _name.text.trim(),
      contact: _email.text.trim().toLowerCase(),
      telephone: _phone.text.trim(),
      role: widget.role,
      nomAtelier: _isMechanic ? _atelier.text.trim() : null,
      typesMoto: _selectedTypes.toList(),
    );
    try {
      final created = await ref
          .read(authServiceProvider)
          .signUp(utilisateur: user, motDePasse: _password.text);
      if (mounted) context.go('/home/${created.role.routeSegment}');
    } on AuthException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _password,
      _confirmation,
      _atelier,
    ]) {
      controller
        ..removeListener(_onChanged)
        ..dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Créer un compte',
      subtitle: 'Inscription · ${widget.role.label}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _name,
              focusNode: _focusNodes[0],
              label: 'Nom complet',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onFieldSubmitted: (_) => _focusNodes[1].requestFocus(),
              validator: validateName,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _phone,
              focusNode: _focusNodes[1],
              label: 'Téléphone',
              hint: 'Ex. 06 12 34 56 78',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              onFieldSubmitted: (_) => _focusNodes[2].requestFocus(),
              validator: validatePhone,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _email,
              focusNode: _focusNodes[2],
              label: 'Adresse e-mail',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _focusNodes[3].requestFocus(),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              focusNode: _focusNodes[3],
              label: 'Mot de passe',
              textInputAction: TextInputAction.next,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => _focusNodes[4].requestFocus(),
              validator: validatePassword,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmation,
              focusNode: _focusNodes[4],
              label: 'Confirmer le mot de passe',
              textInputAction: _isMechanic
                  ? TextInputAction.next
                  : TextInputAction.done,
              obscureText: _obscureConfirmation,
              onFieldSubmitted: (_) {
                if (_isMechanic) {
                  _focusNodes[5].requestFocus();
                } else {
                  _submit();
                }
              },
              validator: _validateConfirmation,
              suffixIcon: IconButton(
                tooltip: _obscureConfirmation
                    ? 'Afficher la confirmation'
                    : 'Masquer la confirmation',
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                icon: Icon(
                  _obscureConfirmation
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            if (_isMechanic) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _atelier,
                focusNode: _focusNodes[5],
                label: 'Nom de l’atelier',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                validator: _validateWorkshop,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Text(
                'Types de moto réparés',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Choisissez au moins un type.',
                style: TextStyle(color: AppColors.texteDoux),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _typesMoto.map((type) {
                  final selected = _selectedTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: selected,
                    showCheckmark: true,
                    onSelected: (value) => setState(() {
                      if (value) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    }),
                    selectedColor: AppColors.orangePale,
                    side: const BorderSide(color: AppColors.bordure),
                  );
                }).toList(),
              ),
              if (_selectedTypes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Sélectionnez au moins un type de moto réparé.',
                    style: TextStyle(color: AppColors.erreur, fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              title: const Text(
                'J’accepte les conditions d’utilisation',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: !_acceptedTerms
                  ? const Text(
                      'Cochez cette case pour continuer.',
                      style: TextStyle(color: AppColors.erreur),
                    )
                  : null,
              minTileHeight: 56,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/legal/terms'),
                child: const Text('Lire les conditions d’utilisation'),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              InlineError(message: _submitError!),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Créer mon compte',
              onPressed: _valid ? _submit : null,
              isLoading: _loading,
            ),
            const SizedBox(height: 12),
            Center(
              child: authLink(
                context,
                text: 'J’ai déjà un compte : me connecter',
                onPressed: () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
