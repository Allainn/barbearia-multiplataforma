// Os três estados que toda tela com dados mostra: carregando, vazio e erro.
// O enunciado não aceita tela branca; usar estes widgets deixa todas as features iguais.
import 'package:flutter/material.dart';

import '../../data/api_exception.dart';
import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Carregando',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;

  /// Ex.: botão "Limpar filtros".
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _MessageView(icon: icon, title: title, message: message, action: action);
}

/// Mostra qualquer erro; [ApiException] ganha ícone e texto próprios.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final (icon, title) = switch (api?.kind) {
      ApiErrorKind.offline => (Icons.wifi_off_rounded, 'Sem conexão'),
      ApiErrorKind.unauthorized => (Icons.lock_outline, 'Entre na sua conta'),
      ApiErrorKind.forbidden => (Icons.block, 'Acesso negado'),
      ApiErrorKind.notFound => (Icons.search_off, 'Não encontrado'),
      ApiErrorKind.conflict => (Icons.event_busy, 'Horário indisponível'),
      ApiErrorKind.unavailable => (Icons.cloud_off, 'Serviço fora do ar'),
      _ => (Icons.error_outline, 'Algo deu errado'),
    };
    return Semantics(
      liveRegion: true,
      child: _MessageView(
        icon: icon,
        title: title,
        message: api?.message ?? 'Tente de novo em instantes.',
        isError: true,
        action: onRetry == null
            ? null
            : FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: isError
                    ? scheme.errorContainer
                    : scheme.secondaryContainer,
                child: Icon(
                  icon,
                  size: 36,
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
