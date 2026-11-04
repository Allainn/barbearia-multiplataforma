import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../state/theme_controller.dart';
import '../theme/app_theme.dart';

/// Tela inicial provisória: mostra a marca, o back-end configurado e a troca de tema.
/// Some quando a feature de lista entrar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.config,
    required this.themeController,
  });

  final AppConfig config;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BarberHub'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => themeController.toggle(theme.brightness),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _Banner(),
            const SizedBox(height: AppSpacing.lg),
            Text('Back-end', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('BFF'),
                    subtitle: Text(config.bffUrl.toString()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Keycloak'),
                    subtitle: Text(
                      '${config.keycloakUrl} · realm ${config.realm}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Para trocar, rode com --dart-define=BFF_URL=... (ver README).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.content_cut, size: 40, color: scheme.onPrimaryContainer),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Seu horário na barbearia, sem fila',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Esqueleto do app. Lista, detalhe, busca, filtro, favoritos e '
            'reserva entram aqui, uma feature por PR.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
