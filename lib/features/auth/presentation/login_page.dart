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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() => _submitError = null);
  }

  bool get _valid =>
      validateEmail(_emailController.text) == null &&
      _passwordController.text.isNotEmpty;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
    return validateEmail(email);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Saisissez votre mot de passe.';
    return null;
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _submitError = null;
    });
    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(
            identifiant: _emailController.text,
            motDePasse: _passwordController.text,
          );
      if (mounted) context.go('/home/${user.role.routeSegment}');
    } on AuthException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController
      ..removeListener(_onChanged)
      ..dispose();
    _passwordController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Ravi de vous revoir',
      subtitle: 'Connectez-vous pour retrouver votre historique.',
      showBack: false,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _emailController,
              label: 'Adresse e-mail',
              hint: 'nom@domaine.fr',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _passwordController,
              label: 'Mot de passe',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submit(),
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
            Align(
              alignment: Alignment.centerRight,
              child: authLink(
                context,
                text: 'Mot de passe oublié ?',
                onPressed: () => context.push('/forgot-password'),
              ),
            ),
            if (_submitError != null) ...[
              InlineError(message: _submitError!),
              const SizedBox(height: 16),
            ],
            AppPrimaryButton(
              label: 'Se connecter',
              onPressed: _valid ? _submit : null,
              isLoading: _loading,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: authLink(
                context,
                text: 'Créer un compte',
                onPressed: () => context.push('/role'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
