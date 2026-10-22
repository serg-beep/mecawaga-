import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'contact@mecawaga.com',
      queryParameters: {'subject': 'Support MecaWaga'},
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('À propos')),
    body: FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? 'Version indisponible'
            : 'Version ${info.version} (${info.buildNumber})';
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Image.asset('assets/images/logo.png', height: 92),
            const SizedBox(height: AppSpacing.lg),
            Text('MecaWaga', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(version, style: const TextStyle(color: AppColors.texteDoux)),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contacter le support'),
              subtitle: const Text('contact@mecawaga.com'),
              onTap: _contact,
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Politique de confidentialité'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/legal/privacy'),
            ),
          ],
        );
      },
    ),
  );
}
