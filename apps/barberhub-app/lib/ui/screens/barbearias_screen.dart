import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../../state/async_state.dart';
import '../../state/barbearias_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barbearia_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Aba "Barbearias": a lista que vem do `GET /barbearias`, com a busca por nome e o
/// filtro por bairro.
class BarbeariasScreen extends StatefulWidget {
  const BarbeariasScreen({
    super.key,
    required this.controller,
    required this.onAbrir,
  });

  final BarbeariasController controller;

  /// Tocar num cartão abre o detalhe por cima das abas.
  final ValueChanged<Barbearia> onAbrir;

  @override
  State<BarbeariasScreen> createState() => _BarbeariasScreenState();
}

class _BarbeariasScreenState extends State<BarbeariasScreen> {
  late final _campoBusca = TextEditingController(text: _controller.busca);

  BarbeariasController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // A aba nasce logo depois do login: é a hora de buscar com o token novo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.carregar());
  }

  @override
  void dispose() {
    _campoBusca.dispose();
    super.dispose();
  }

  void _limparFiltros() {
    _campoBusca.clear();
    _controller.limparFiltros();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barbearias')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => switch (_controller.estado) {
          AsyncLoading() => const SkeletonList(),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: _controller.carregar,
          ),
          AsyncData() => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _campoBusca,
                  onChanged: _controller.buscar,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar barbearia pelo nome',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.busca.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar a busca',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _campoBusca.clear();
                              _controller.buscar('');
                            },
                          ),
                  ),
                ),
              ),
              if (_controller.bairros.isNotEmpty)
                _FiltroDeBairro(
                  bairros: _controller.bairros,
                  selecionado: _controller.bairro,
                  onSelecionar: _controller.filtrarPorBairro,
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _controller.carregar(silencioso: true),
                  child: _Lista(
                    barbearias: _controller.visiveis,
                    filtrando: _controller.filtrando,
                    onAbrir: widget.onAbrir,
                    onLimparFiltros: _limparFiltros,
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// Chips de bairro numa linha que rola para o lado.
class _FiltroDeBairro extends StatelessWidget {
  const _FiltroDeBairro({
    required this.bairros,
    required this.selecionado,
    required this.onSelecionar,
  });

  final List<String> bairros;
  final String? selecionado;
  final ValueChanged<String?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Filtrar por bairro',
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            for (final (i, bairro) in bairros.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              FilterChip(
                label: Text(bairro),
                selected: bairro == selecionado,
                onSelected: (_) => onSelecionar(bairro),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.barbearias,
    required this.filtrando,
    required this.onAbrir,
    required this.onLimparFiltros,
  });

  final List<Barbearia> barbearias;

  /// Lista vazia por causa da busca ou do filtro, e não porque o back-end está vazio.
  final bool filtrando;
  final ValueChanged<Barbearia> onAbrir;
  final VoidCallback onLimparFiltros;

  @override
  Widget build(BuildContext context) {
    if (barbearias.isEmpty) {
      // Dentro de uma lista rolável, para o "puxar para atualizar" funcionar no vazio.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: filtrando
                ? EmptyView(
                    icon: Icons.search_off,
                    title: 'Nenhuma barbearia encontrada',
                    message: 'Tente outro nome ou limpe os filtros.',
                    action: TextButton(
                      onPressed: onLimparFiltros,
                      child: const Text('Limpar filtros'),
                    ),
                  )
                : const EmptyView(
                    icon: Icons.storefront_outlined,
                    title: 'Nenhuma barbearia cadastrada',
                    message: 'Puxe para baixo para atualizar.',
                  ),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: barbearias.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => BarbeariaCard(
        barbearia: barbearias[i],
        onTap: () => onAbrir(barbearias[i]),
      ),
    );
  }
}
