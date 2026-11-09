import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../core/formatters.dart';
import '../../data/api_exception.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/barbearia.dart';
import '../../data/models/profissional.dart';
import '../../data/models/servico.dart';
import '../../state/async_state.dart';
import '../../state/horarios.dart';
import '../../state/reserva_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Reserva: escolher serviço, profissional, dia e horário, e confirmar.
///
/// Devolve o [Agendamento] criado para quem abriu a tela (`Navigator.pop`).
class ReservaScreen extends StatefulWidget {
  const ReservaScreen({
    super.key,
    required this.barbearia,
    required this.profissionais,
    required this.servicos,
    required this.dependencies,
    this.servicoInicial,
  });

  final Barbearia barbearia;
  final List<Profissional> profissionais;
  final List<Servico> servicos;
  final AppDependencies dependencies;

  /// Serviço já marcado ao abrir (o usuário tocou nele no detalhe).
  final Servico? servicoInicial;

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  late final _controller = ReservaController(
    barbearia: widget.barbearia,
    profissionais: widget.profissionais,
    servicos: widget.servicos,
    disponibilidade: widget.dependencies.disponibilidadeRepository,
    agendamentos: widget.dependencies.agendamentoRepository,
    servicoInicial: widget.servicoInicial,
  );

  @override
  void initState() {
    super.initState();
    _controller.iniciar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final servico = _controller.servico;
    final profissional = _controller.profissional;
    final agendamento = await _controller.reservar();
    if (agendamento == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Reserva confirmada'),
        content: Text(
          '${servico.nome} com ${profissional.nome}\n'
          '${_quando(agendamento.inicio)}\n'
          '${widget.barbearia.nome}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(agendamento);
  }

  @override
  Widget build(BuildContext context) {
    const margem = EdgeInsets.symmetric(horizontal: AppSpacing.md);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final agora = _controller.agora;
        return Scaffold(
          appBar: AppBar(title: const Text('Reservar horário')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Padding(
                padding: margem,
                child: Text(
                  widget.barbearia.nome,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SectionHeader(title: 'Serviço'),
              Padding(
                padding: margem,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final servico in _controller.servicos)
                      ChoiceChip(
                        label: Text(
                          '${servico.nome} · ${formatPreco(servico.preco)}',
                        ),
                        selected: servico == _controller.servico,
                        onSelected: (_) => _controller.escolherServico(servico),
                      ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Profissional'),
              Padding(
                padding: margem,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final profissional in _controller.profissionais)
                      ChoiceChip(
                        label: Text(profissional.nome),
                        selected: profissional == _controller.profissional,
                        onSelected: (_) =>
                            _controller.escolherProfissional(profissional),
                      ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Dia'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: margem,
                child: Row(
                  children: [
                    for (final (i, dia) in _controller.dias.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      ChoiceChip(
                        label: Text(rotuloDoDia(dia, agora)),
                        selected: dia == _controller.dia,
                        onSelected: (_) => _controller.escolherDia(dia),
                      ),
                    ],
                  ],
                ),
              ),
              SectionHeader(
                title:
                    'Horário · ${formatDuracao(_controller.servico.duracaoMin)}',
              ),
              if (_controller.falha case final falha?)
                Padding(
                  padding: margem.copyWith(bottom: AppSpacing.md),
                  child: _AvisoDeFalha(falha: falha),
                ),
              switch (_controller.horarios) {
                AsyncLoading() => const Padding(
                  padding: margem,
                  child: _HorariosCarregando(),
                ),
                AsyncError(:final error) => SizedBox(
                  height: 320,
                  child: ErrorView(
                    error: error,
                    onRetry: _controller.carregarHorarios,
                  ),
                ),
                AsyncData(:final value) when value.isEmpty => const SizedBox(
                  height: 260,
                  child: EmptyView(
                    icon: Icons.event_busy,
                    title: 'Sem horários livres',
                    message: 'Escolha outro dia ou outro profissional.',
                  ),
                ),
                AsyncData(:final value) => Padding(
                  padding: margem,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final horario in value)
                        ChoiceChip(
                          label: Text(formatHora(horario.inicio)),
                          selected: horario == _controller.horario,
                          onSelected: _controller.reservando
                              ? null
                              : (_) => _controller.escolherHorario(horario),
                        ),
                    ],
                  ),
                ),
              },
            ],
          ),
          bottomNavigationBar: _BarraDeConfirmacao(
            resumo: _resumo(),
            reservando: _controller.reservando,
            onConfirmar: _controller.horario == null ? null : _confirmar,
          ),
        );
      },
    );
  }

  String _resumo() {
    final horario = _controller.horario;
    if (horario == null) return 'Escolha um horário para continuar.';
    return '${_quando(horario.inicio)} · ${_controller.servico.nome} com '
        '${_controller.profissional.nome}';
  }
}

/// `ter., 10 de nov. às 10:00`, no relógio da barbearia.
String _quando(DateTime inicio) =>
    '${formatDia(naBarbearia(inicio))} às ${formatHora(inicio)}';

/// Mensagem da reserva que falhou. O 409 ganha título próprio: é a disputa de horário.
class _AvisoDeFalha extends StatelessWidget {
  const _AvisoDeFalha({required this.falha});

  final ApiException falha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final conflito = falha.kind == ApiErrorKind.conflict;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              conflito ? Icons.event_busy : Icons.error_outline,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conflito
                        ? 'Esse horário acabou de ser reservado'
                        : 'Não foi possível reservar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    conflito
                        ? 'Outro cliente confirmou primeiro. Atualizamos a lista: '
                              'escolha outro horário.'
                        : falha.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton com a forma dos chips de horário.
class _HorariosCarregando extends StatelessWidget {
  const _HorariosCarregando();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < 12; i++)
            const SkeletonBox(width: 72, height: 40, radius: AppRadius.lg),
        ],
      ),
    );
  }
}

class _BarraDeConfirmacao extends StatelessWidget {
  const _BarraDeConfirmacao({
    required this.resumo,
    required this.reservando,
    required this.onConfirmar,
  });

  final String resumo;
  final bool reservando;
  final VoidCallback? onConfirmar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                resumo,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: reservando ? null : onConfirmar,
                child: reservando
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Confirmar reserva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
