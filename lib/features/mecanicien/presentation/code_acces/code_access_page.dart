import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../../proprietaire/domain/code_acces.dart';
import '../../data/mecanicien_providers.dart';
import '../../data/mecanicien_repository.dart';
import '../../domain/moto_client.dart';

class CodeAccessPage extends ConsumerStatefulWidget {
  const CodeAccessPage({super.key});

  @override
  ConsumerState<CodeAccessPage> createState() => _CodeAccessPageState();
}

class _CodeAccessPageState extends ConsumerState<CodeAccessPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  bool get _isValid => RegExp(
    r'^MOTO-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$',
  ).hasMatch(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = await ref
          .read(mecanicienRepositoryProvider)
          .findMotoWithCode(
            _controller.text.trim().toUpperCase(),
            ref.read(mecanicienProfilProvider),
          );
      if (!mounted) return;
      context.push('/mechanic/code/confirmation', extra: client);
    } on CodeAccesMecanicienException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Impossible de vérifier le code : $error. Réessayez dans un instant.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: 'Saisir un code d’accès',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const StateMessage(
          icon: Icons.key_outlined,
          title: 'Consulter l’historique d’une moto',
          message:
              'Demandez au propriétaire son code d’accès temporaire au format MOTO-XXXXXX.',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          keyboardType: TextInputType.text,
          inputFormatters: [
            _MotoCodeFormatter(),
            LengthLimitingTextInputFormatter(11),
          ],
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Code d’accès',
            hintText: 'MOTO-4F9K2T',
            prefixIcon: const Icon(Icons.key),
            errorText: _error,
            helperText:
                _error == null && _controller.text.isNotEmpty && !_isValid
                ? 'Saisissez six caractères après MOTO-, sans 0, O, 1, I ni L.'
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isValid && !_loading ? _submit : null,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Vérifier le code'),
          ),
        ),
      ],
    ),
  );
}

class _MotoCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase().replaceAll(' ', '');
    final rawSuffix = upper.startsWith('MOTO') ? upper.substring(4) : upper;
    final suffix = rawSuffix.replaceAll(RegExp('[^$codeAccesAlphabet]'), '');
    final normalizedSuffix = suffix.length > codeAccesLongueur
        ? suffix.substring(0, codeAccesLongueur)
        : suffix;
    final value = '$codeAccesPrefixe$normalizedSuffix';
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class CodeAccessConfirmationPage extends ConsumerStatefulWidget {
  const CodeAccessConfirmationPage({required this.client, super.key});

  final MotoClient client;

  @override
  ConsumerState<CodeAccessConfirmationPage> createState() =>
      _CodeAccessConfirmationPageState();
}

class _CodeAccessConfirmationPageState
    extends ConsumerState<CodeAccessConfirmationPage> {
  bool _loading = false;
  String? _error;

  Future<void> _addClient() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(mecanicienRepositoryProvider)
          .addClient(widget.client, ref.read(mecanicienProfilProvider));
      if (!mounted) return;
      ref.invalidate(
        mecanicienClientsProvider(ref.read(mecanicienProfilProvider).id),
      );
      context.go('/mechanic');
    } on CodeAccesMecanicienException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Impossible d’ajouter cette moto : $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: 'Confirmer l’accès',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        OwnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.two_wheeler_outlined,
                size: 38,
                color: AppColors.bleu,
              ),
              const SizedBox(height: 12),
              Text(
                widget.client.moto.nom,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.client.moto.immatriculation,
                style: const TextStyle(
                  color: AppColors.texteDoux,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Propriétaire : ${widget.client.proprietaire}'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.client.moto.kilometrage} km',
                style: const TextStyle(color: AppColors.texteDoux),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.erreur),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _addClient,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.texte,
            ),
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Ajouter à mes clients'),
          ),
        ),
      ],
    ),
  );
}
