import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/api_exception.dart';
import '../../data/models/reserva_local.dart';
import '../../state/agendamentos_controller.dart';
import '../../state/async_state.dart';
import '../../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Aba "Agendamentos": as reservas da conta logada, lidas do `GET /agendamentos`, com o
/// cancelamento pelo `DELETE /agendamentos/{id}`.
///
/// Abre no carregando e mostra vazio ou erro como as outras abas. Sem rede, mostra o que
/// ficou no aparelho com um aviso, em vez de um erro sem nada.
class AgendamentosScreen extends StatefulWidget {
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

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen> {
  AgendamentosController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // As abas nascem logo depois do login: é a hora de buscar com o token novo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar({bool silencioso = false}) async {
    final clienteId = widget.auth.sessao?.userId;
    if (clienteId == null) return;
    await _controller.carregar(clienteId, silencioso: silencioso);
  }

  Future<void> _cancelar(BuildContext context, ReservaLocal reserva) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar esta reserva?'),
        content: Text(
          '${_servicoComProfissional(reserva)}\n'
          '${_quando(reserva)}\n'
          '${_barbearia(reserva)}\n\n'
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
      await _controller.cancelar(reserva);
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
        listenable: Listenable.merge([_controller, widget.auth]),
        builder: (context, _) {
          final clienteId = widget.auth.sessao?.userId;
          // saindo: o login já vai aparecer
          if (clienteId == null) return const SizedBox.shrink();
          return switch (_controller.estado(clienteId)) {
            AsyncLoading() => const SkeletonList(),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: _carregar,
            ),
            AsyncData() => RefreshIndicator(
              onRefresh: () => _carregar(silencioso: true),
              child: _lista(context, clienteId),
            ),
          };
        },
      ),
    );
  }

  Widget _lista(BuildContext context, String clienteId) {
    final agora = widget.agora();
    final proximas = _controller.proximas(clienteId, agora);
    final historico = _controller.historico(clienteId, agora);
    final aviso = _controller.desatualizado
        ? const _AvisoDesatualizado()
        : null;
    if (proximas.isEmpty && historico.isEmpty) {
      // Dentro de uma lista rolável, para o "puxar para atualizar" funcionar no vazio.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Column(
              children: [
                ?aviso,
                Expanded(
                  child: EmptyView(
                    icon: Icons.event_note_outlined,
                    title: 'Nenhum agendamento',
                    message:
                        'Suas reservas aparecem aqui. Escolha uma barbearia para '
                        'reservar seu horário.',
                    action: FilledButton.tonal(
                      onPressed: widget.onVerBarbearias,
                      child: const Text('Ver barbearias'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        ?aviso,
        const SectionHeader(title: 'Próximos'),
        if (proximas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
            cancelando: _controller.cancelando(reserva),
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
  }
}

/// A leitura do servidor falhou e a lista é a que ficou no aparelho: um cancelamento
/// feito por fora, ou uma reserva de outro aparelho, pode não estar aqui.
class _AvisoDesatualizado extends StatelessWidget {
  const _AvisoDesatualizado();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Sem resposta do servidor. Estas são as reservas salvas neste '
                'aparelho e podem estar desatualizadas. Puxe para atualizar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os nomes que faltam (reserva de outro aparelho com o catálogo fora do ar) viram texto
/// neutro: a reserva aparece do mesmo jeito.
String _barbearia(ReservaLocal reserva) =>
    reserva.barbeariaNome ?? 'Barbearia não identificada';

String _servicoComProfissional(ReservaLocal reserva) {
  final servico = reserva.servicoNome;
  final profissional = reserva.profissionalNome;
  if (servico == null && profissional == null) {
    return 'Detalhes indisponíveis no momento';
  }
  return '${servico ?? 'Serviço'} com ${profissional ?? 'profissional'}';
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
                _barbearia(reserva),
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: situacao == _Situacao.cancelada
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _servicoComProfissional(reserva),
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
                  if (reserva.preco case final preco?)
                    InfoChip(label: formatPreco(preco), highlight: ativa),
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
