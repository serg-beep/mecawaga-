import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/code_acces.dart';
import '../owner_widgets.dart';

class CodeAccessPage extends ConsumerStatefulWidget {
  const CodeAccessPage({required this.motoId, super.key});
  final String motoId;

  @override
  ConsumerState<CodeAccessPage> createState() => _CodeAccessPageState();
}

class _CodeAccessPageState extends ConsumerState<CodeAccessPage> {
  CodeAcces? _code;
  List<AccesMecanicien> _access = [];
  bool _loading = true;
  String? _error;
  Timer? _ticker;
  bool _operationLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(proprietaireRepositoryProvider);
      _code = await repo.getAccessCode(widget.motoId);
      _access = await repo.getMechanicAccess(widget.motoId);
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger les accès. Réessayez.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _generate() async {
    if (_operationLoading) return;
    if (_code != null && !_code!.estExpire) {
      final confirmed = await confirmerActionIrreversible(
        context,
        titre: 'Générer un nouveau code ?',
        message:
            'Le code ${_code!.code} sera immédiatement invalidé. Tout mécanicien qui ne l’a pas encore saisi devra demander le nouveau code.',
        confirmation: 'Générer un nouveau code',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _operationLoading = true);
    try {
      _code = await ref
          .read(proprietaireRepositoryProvider)
          .createAccessCode(widget.motoId);
      await _load();
      if (mounted && _error == null) {
        afficherConfirmation(context, 'Un nouveau code d’accès a été généré.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Le code n’a pas pu être généré. Réessayez.';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _operationLoading = false);
    }
  }

  String get _remaining {
    final duration = _code!.expiration.difference(DateTime.now());
    if (duration.isNegative) return 'Code expiré';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds restantes';
  }

  Future<void> _revoke(AccesMecanicien access) async {
    final confirmed = await confirmerActionIrreversible(
      context,
      titre: 'Retirer l’accès ?',
      message:
          '${access.mecanicien.nomAtelier} ne pourra plus consulter cet historique.',
      confirmation: 'Retirer l’accès',
    );
    if (!confirmed || _operationLoading) return;
    setState(() => _operationLoading = true);
    try {
      await ref
          .read(proprietaireRepositoryProvider)
          .revokeMechanicAccess(widget.motoId, access.mecanicien.id);
      await _load();
      if (mounted && _error == null) {
        afficherConfirmation(context, 'L’accès du mécanicien a été retiré.');
      }
    } on Exception {
      if (mounted) {
        afficherConfirmation(
          context,
          'Impossible de retirer l’accès. Vérifiez votre connexion puis réessayez.',
          erreur: true,
        );
      }
    } finally {
      if (mounted) setState(() => _operationLoading = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: 'Partager l’historique',
    child: _loading
        ? const EtatChargement(rows: 2)
        : _error != null
        ? StateMessage(
            icon: Icons.error_outline,
            title: 'Erreur de chargement',
            message: _error!,
            action: FilledButton(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          )
        : _accessList(context),
  );

  Widget _accessList(BuildContext context) {
    final items = <WidgetBuilder>[
      (context) => Text(
        'Code temporaire',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      (_) => const SizedBox(height: AppSpacing.sm),
      (_) => const Text(
        'Communiquez ce code à votre mécanicien pour lui donner accès à l’historique pendant 24 heures.',
        style: TextStyle(color: AppColors.texteDoux, height: 1.5),
      ),
      (_) => const SizedBox(height: AppSpacing.lg),
      (context) => _code == null || _code!.estExpire
          ? AppPrimaryAction(
              label: _code == null
                  ? 'Générer un code d’accès'
                  : 'Générer un nouveau code',
              onPressed: _generate,
              isLoading: _operationLoading,
            )
          : OwnerCard(
              child: Column(
                children: [
                  Text(
                    _code!.code,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.bleu,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _remaining,
                    style: const TextStyle(color: AppColors.texteDoux),
                  ),
                  Text(
                    'Expire le ${DateFormat('d MMM à HH:mm', 'fr_FR').format(_code!.expiration)}',
                    style: const TextStyle(color: AppColors.texteDoux),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _code!.code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copié.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier'),
                  ),
                  TextButton(
                    onPressed: _operationLoading ? null : _generate,
                    child: const Text('Générer un nouveau code'),
                  ),
                ],
              ),
            ),
      (_) => const SizedBox(height: AppSpacing.xxl),
      (context) => Text(
        'Mécaniciens autorisés',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      (_) => const SizedBox(height: AppSpacing.sm),
    ];
    if (_access.isEmpty) {
      items.add(
        (_) => const Text(
          'Aucun mécanicien n’a accès à cet historique. Partagez un code pour autoriser un atelier.',
          style: TextStyle(color: AppColors.texteDoux, height: 1.5),
        ),
      );
    } else {
      for (final access in _access) {
        items.add(
          (_) => OwnerCard(
            child: Row(
              children: [
                const Icon(Icons.build_outlined, color: AppColors.bleu),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    access.mecanicien.nomAtelier,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _operationLoading ? null : () => _revoke(access),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.erreur,
                  ),
                  child: const Text('Retirer l’accès'),
                ),
              ],
            ),
          ),
        );
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index](context),
    );
  }
}

class AppPrimaryAction extends StatelessWidget {
  const AppPrimaryAction({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.texte,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.texte,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}
