import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_providers.dart';
import 'auth_components.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on Exception {
      if (mounted) {
        setState(() {
          _submitError =
              'Le lien n’a pas pu être envoyé. Vérifiez votre connexion puis réessayez.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: _sent ? 'Vérifiez votre boîte mail' : 'Mot de passe oublié',
      subtitle: _sent
          ? 'Un lien de réinitialisation a été envoyé.'
          : 'Saisissez l’adresse e-mail associée à votre compte.',
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.bleu.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.bleu,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Un lien de réinitialisation a été envoyé. Consultez votre boîte de réception.',
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: 'Retour à la connexion',
                  onPressed: () => context.go('/login'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _emailController,
                    label: 'Adresse e-mail',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    InlineError(message: _submitError!),
                  ],
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Envoyer le lien',
                    onPressed: validateEmail(_emailController.text) == null
                        ? _submit
                        : null,
                    isLoading: _loading,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: authLink(
                      context,
                      text: 'Retour à la connexion',
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
