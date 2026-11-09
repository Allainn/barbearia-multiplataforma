import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../core/formatters.dart';
import '../../data/models/barbearia.dart';
import '../../data/models/profissional.dart';
import '../../data/models/servico.dart';
import '../../state/async_state.dart';
import '../../state/barbearia_detalhe_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/monogram.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Detalhe de uma barbearia: serviços (com duração e preço) e profissionais.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
    );
  }

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
          itemBuilder: (context, i) =>
              _ServicoTile(servico: detalhe.servicos[i]),
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
  const _ServicoTile({required this.servico});

  final Servico servico;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
