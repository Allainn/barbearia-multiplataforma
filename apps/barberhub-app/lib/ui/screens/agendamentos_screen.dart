import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/api_exception.dart';
import '../../data/models/reserva_local.dart';
import '../../state/agendamentos_controller.dart';
import '../../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

/// Aba "Agendamentos": as reservas feitas neste aparelho pela conta logada, com o
/// cancelamento pelo `DELETE /agendamentos/{id}`.
///
/// A lista vem do aparelho (o contrato não tem rota de listagem), então abre sem esperar
/// rede; o carregando e o erro aparecem no cancelamento, que é a chamada ao BFF.
class AgendamentosScreen extends StatelessWidget {
  const AgendamentosScreen({
    super.key,
    required this.controller,
    required this.auth,
    required this.onVerBarbearias,
    this.agora = DateTime.now,
  });

  final AgendamentosController controller;
  final AuthController auth;
  final VoidCallback onVerBarbearias;
  final DateTime Function() agora;

  Future<void> _cancelar(BuildContext context, ReservaLocal reserva) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar esta reserva?'),
        content: Text(
          '${reserva.servicoNome} com ${reserva.profissionalNome}\n'
          '${_quando(reserva)}\n'
          '${reserva.barbeariaNome}\n\n'
          'O horário volta a ficar livre para outros clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.cancelar(reserva);
      messenger.showSnackBar(
        const SnackBar(content: Text('Reserva cancelada.')),
      );
    } on ApiException catch (erro) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível cancelar. ${erro.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendamentos')),
      body: ListenableBuilder(
        listenable: Listenable.merge([controller, auth]),
        builder: (context, _) {
          final clienteId = auth.sessao?.userId;
          // saindo: o login já vai aparecer
          if (clienteId == null) return const SizedBox.shrink();
          final agora = this.agora();
          final proximas = controller.proximas(clienteId, agora);
          final historico = controller.historico(clienteId, agora);
          if (proximas.isEmpty && historico.isEmpty) {
            return EmptyView(
              icon: Icons.event_note_outlined,
              title: 'Nenhum agendamento',
              message:
                  'As reservas feitas neste aparelho aparecem aqui. Escolha uma '
                  'barbearia para reservar seu horário.',
              action: FilledButton.tonal(
                onPressed: onVerBarbearias,
                child: const Text('Ver barbearias'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              const SectionHeader(title: 'Próximos'),
              if (proximas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'Nenhuma reserva por vir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final reserva in proximas)
                _ReservaCard(
                  reserva: reserva,
                  situacao: _Situacao.confirmada,
                  cancelando: controller.cancelando(reserva),
                  onCancelar: () => _cancelar(context, reserva),
                ),
              if (historico.isNotEmpty) ...[
                const SectionHeader(title: 'Histórico'),
                for (final reserva in historico)
                  _ReservaCard(
                    reserva: reserva,
                    situacao: reserva.cancelada
                        ? _Situacao.cancelada
                        : _Situacao.concluida,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// `ter., 10 de nov. · 10:00–11:00`, no relógio da barbearia.
String _quando(ReservaLocal reserva) {
  final inicio = reserva.agendamento.inicio;
  return '${formatDia(naBarbearia(inicio))} · ${formatHora(inicio)}–'
      '${formatHora(reserva.agendamento.fim)}';
}

enum _Situacao {
  confirmada('Confirmada', Icons.check_circle_outline),
  concluida('Concluída', Icons.history),
  cancelada('Cancelada', Icons.cancel_outlined);

  const _Situacao(this.rotulo, this.icone);

  final String rotulo;
  final IconData icone;
}

class _ReservaCard extends StatelessWidget {
  const _ReservaCard({
    required this.reserva,
    required this.situacao,
    this.cancelando = false,
    this.onCancelar,
  });

  final ReservaLocal reserva;
  final _Situacao situacao;
  final bool cancelando;

  /// Null no histórico: reserva passada ou já cancelada não tem o que cancelar.
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ativa = situacao == _Situacao.confirmada;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _quando(reserva),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ativa ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                reserva.barbeariaNome,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: situacao == _Situacao.cancelada
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${reserva.servicoNome} com ${reserva.profissionalNome}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  InfoChip(icon: situacao.icone, label: situacao.rotulo),
                  InfoChip(label: formatPreco(reserva.preco), highlight: ativa),
                ],
              ),
              if (onCancelar != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: cancelando ? null : onCancelar,
                    icon: cancelando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_busy),
                    label: Text(cancelando ? 'Cancelando...' : 'Cancelar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
