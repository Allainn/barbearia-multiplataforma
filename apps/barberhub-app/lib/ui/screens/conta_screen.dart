import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import 'guia_visual_screen.dart';

/// Aba "Conta": login (feature 1), aparência, back-end em uso e o guia visual.
class ContaScreen extends StatelessWidget {
  const ContaScreen({
    super.key,
    required this.config,
    required this.themeController,
  });

  final AppConfig config;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text('Você ainda não entrou'),
            subtitle: Text('O login com o Keycloak entra aqui (feature 1).'),
          ),
          const SectionHeader(title: 'Aparência'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeController,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Sistema'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Escuro'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (escolha) =>
                    themeController.setMode(escolha.single),
              ),
            ),
          ),
          const SectionHeader(title: 'Back-end'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('BFF'),
            subtitle: Text(config.bffUrl.toString()),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Keycloak'),
            subtitle: Text('${config.keycloakUrl} · realm ${config.realm}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Para trocar, rode com --dart-define=BFF_URL=... (ver README).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SectionHeader(title: 'Para o grupo'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Guia visual'),
            subtitle: const Text('Cores, fontes e componentes do app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuiaVisualScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
