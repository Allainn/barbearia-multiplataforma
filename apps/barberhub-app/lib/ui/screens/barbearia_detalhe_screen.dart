import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../core/formatters.dart';
import '../../data/models/barbearia.dart';
import '../../data/models/profissional.dart';
import '../../data/models/servico.dart';
import '../../state/async_state.dart';
import '../../state/barbearia_detalhe_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/favorito_button.dart';
import '../widgets/info_chip.dart';
import '../widgets/monogram.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';
import 'reserva_screen.dart';

/// Detalhe de uma barbearia: serviços (com duração e preço) e profissionais. É daqui que
/// a reserva começa.
class BarbeariaDetalheScreen extends StatefulWidget {
  const BarbeariaDetalheScreen({
    super.key,
    required this.barbearia,
    required this.dependencies,
  });

  final Barbearia barbearia;
  final AppDependencies dependencies;

  @override
  State<BarbeariaDetalheScreen> createState() => _BarbeariaDetalheScreenState();
}

class _BarbeariaDetalheScreenState extends State<BarbeariaDetalheScreen> {
  late final _controller = BarbeariaDetalheController(
    widget.dependencies.barbeariaRepository,
    widget.barbearia,
  );

  @override
  void initState() {
    super.initState();
    _controller.carregar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Abre a reserva, com [servico] já marcado se o usuário tocou num serviço.
  Future<void> _reservar(DetalheBarbearia detalhe, [Servico? servico]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservaScreen(
          barbearia: widget.barbearia,
          profissionais: detalhe.profissionais,
          servicos: detalhe.servicos,
          servicoInicial: servico,
          dependencies: widget.dependencies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          FavoritoButton(
            barbearia: widget.barbearia,
            favoritos: widget.dependencies.favoritos,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Cabecalho(barbearia: widget.barbearia)),
            ...switch (_controller.estado) {
              AsyncLoading() => const [
                SliverFillRemaining(child: SkeletonList(itemCount: 4)),
              ],
              AsyncError(:final error) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(error: error, onRetry: _controller.carregar),
                ),
              ],
              AsyncData(:final value) => _conteudo(value),
            },
          ],
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => switch (_controller.estado) {
          AsyncData(:final value) when value.podeReservar => _BarraDeReserva(
            ehCliente: widget.dependencies.auth.sessao?.ehCliente ?? false,
            onReservar: () => _reservar(value),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  bool _podeReservar(DetalheBarbearia detalhe) =>
      detalhe.podeReservar &&
      (widget.dependencies.auth.sessao?.ehCliente ?? false);

  List<Widget> _conteudo(DetalheBarbearia detalhe) {
    if (detalhe.servicos.isEmpty && detalhe.profissionais.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.content_cut,
            title: 'Barbearia ainda sem agenda',
            message: 'Ela não cadastrou serviços nem profissionais.',
          ),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(child: SectionHeader(title: 'Serviços')),
      if (detalhe.servicos.isEmpty)
        const SliverToBoxAdapter(child: _SemItens('Nenhum serviço cadastrado.'))
      else
        SliverList.builder(
          itemCount: detalhe.servicos.length,
          itemBuilder: (context, i) => _ServicoTile(
            servico: detalhe.servicos[i],
            onTap: _podeReservar(detalhe)
                ? () => _reservar(detalhe, detalhe.servicos[i])
                : null,
          ),
        ),
      const SliverToBoxAdapter(child: SectionHeader(title: 'Profissionais')),
      if (detalhe.profissionais.isEmpty)
        const SliverToBoxAdapter(
          child: _SemItens('Nenhum profissional cadastrado.'),
        )
      else
        SliverList.builder(
          itemCount: detalhe.profissionais.length,
          itemBuilder: (context, i) =>
              _ProfissionalTile(profissional: detalhe.profissionais[i]),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.barbearia});

  final Barbearia barbearia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Monogram(nome: barbearia.nome, size: 72),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    barbearia.nome,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        barbearia.endereco,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicoTile extends StatelessWidget {
  const _ServicoTile({required this.servico, this.onTap});

  final Servico servico;

  /// Abre a reserva com este serviço marcado; null quando não dá para reservar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      title: Text(servico.nome),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            InfoChip(
              icon: Icons.schedule,
              label: formatDuracao(servico.duracaoMin),
            ),
            InfoChip(label: formatPreco(servico.preco), highlight: true),
          ],
        ),
      ),
    );
  }
}

class _ProfissionalTile extends StatelessWidget {
  const _ProfissionalTile({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Monogram(nome: profissional.nome, size: 40),
      title: Text(profissional.nome),
    );
  }
}

class _SemItens extends StatelessWidget {
  const _SemItens(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        texto,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Botão fixo no pé do detalhe. Gestor vê o motivo de não poder reservar: o BFF só aceita
/// `POST /agendamentos` de quem tem a role `cliente`.
class _BarraDeReserva extends StatelessWidget {
  const _BarraDeReserva({required this.ehCliente, required this.onReservar});

  final bool ehCliente;
  final VoidCallback onReservar;

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
              if (!ehCliente) ...[
                Text(
                  'Só contas de cliente reservam horário pelo app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton.icon(
                onPressed: ehCliente ? onReservar : null,
                icon: const Icon(Icons.event_available),
                label: const Text('Reservar horário'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
