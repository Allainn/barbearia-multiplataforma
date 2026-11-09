import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../state/auth_controller.dart';
import '../../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/monogram.dart';
import '../widgets/section_header.dart';
import 'guia_visual_screen.dart';

/// Aba "Conta": quem está logado, aparência, back-end em uso e o guia visual.
class ContaScreen extends StatelessWidget {
  const ContaScreen({
    super.key,
    required this.config,
    required this.themeController,
    required this.auth,
  });

  final AppConfig config;
  final ThemeController themeController;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          ListenableBuilder(
            listenable: auth,
            builder: (context, _) => _Perfil(auth: auth),
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

/// Cartão do usuário logado, com as roles do token e o botão de sair.
class _Perfil extends StatelessWidget {
  const _Perfil({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final sessao = auth.sessao;
    // saindo: o login já vai aparecer
    if (sessao == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Monogram(nome: sessao.nome, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sessao.nome, style: theme.textTheme.titleLarge),
                        Text(
                          sessao.usuario,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (sessao.ehCliente)
                    const InfoChip(
                      icon: Icons.event_available,
                      label: 'Cliente',
                    ),
                  if (sessao.ehGestor)
                    const InfoChip(icon: Icons.storefront, label: 'Gestor'),
                ],
              ),
              if (!sessao.ehCliente) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Só contas de cliente reservam horário pelo app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: auth.sair,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
