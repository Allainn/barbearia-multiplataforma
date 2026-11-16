import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../../state/async_state.dart';
import '../../state/barbearias_controller.dart';
import '../../state/buscas_recentes_controller.dart';
import '../../state/favoritos_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barbearia_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Junta o campo de busca e o painel de recentes: um toque em qualquer um dos dois não
/// conta como "tocar fora".
const _grupoBusca = #buscaBarbearias;

/// Aba "Barbearias": a lista que vem do `GET /barbearias`, com a busca por nome, as
/// buscas recentes e o filtro por bairro.
class BarbeariasScreen extends StatefulWidget {
  const BarbeariasScreen({
    super.key,
    required this.controller,
    required this.buscasRecentes,
    required this.favoritos,
    required this.onAbrir,
  });

  final BarbeariasController controller;
  final BuscasRecentesController buscasRecentes;
  final FavoritosController favoritos;

  /// Tocar num cartão abre o detalhe por cima das abas.
  final ValueChanged<Barbearia> onAbrir;

  @override
  State<BarbeariasScreen> createState() => _BarbeariasScreenState();
}

class _BarbeariasScreenState extends State<BarbeariasScreen> {
  late final _campoBusca = TextEditingController(text: _controller.busca);
  final _focoBusca = FocusNode();

  BarbeariasController get _controller => widget.controller;
  BuscasRecentesController get _recentes => widget.buscasRecentes;

  @override
  void initState() {
    super.initState();
    // A aba nasce logo depois do login: é a hora de buscar com o token novo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.carregar());
  }

  @override
  void dispose() {
    _campoBusca.dispose();
    _focoBusca.dispose();
    super.dispose();
  }

  void _limparFiltros() {
    _campoBusca.clear();
    _controller.limparFiltros();
  }

  /// Com o campo em foco e vazio, as buscas recentes aparecem no lugar da lista.
  bool get _mostrandoRecentes =>
      _focoBusca.hasFocus &&
      _controller.busca.isEmpty &&
      _recentes.recentes.isNotEmpty;

  /// Tocar numa busca recente refaz a busca e fecha o teclado.
  void _usarRecente(String termo) {
    _campoBusca.value = TextEditingValue(
      text: termo,
      selection: TextSelection.collapsed(offset: termo.length),
    );
    _controller.buscar(termo);
    _recentes.registrar(termo);
    _focoBusca.unfocus();
  }

  /// Abrir uma barbearia a partir do resultado conta como busca que deu certo.
  void _abrir(Barbearia barbearia) {
    _recentes.registrar(_controller.busca);
    widget.onAbrir(barbearia);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barbearias')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _recentes, _focoBusca]),
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
                  focusNode: _focoBusca,
                  // Tocar fora do campo e do painel de recentes fecha o teclado e o painel.
                  groupId: _grupoBusca,
                  onTapOutside: (_) => _focoBusca.unfocus(),
                  onChanged: _controller.buscar,
                  onSubmitted: _recentes.registrar,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar barbearia pelo nome',
                    prefixIcon: _mostrandoRecentes
                        ? IconButton(
                            tooltip: 'Fechar buscas recentes',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _focoBusca.unfocus,
                          )
                        : const Icon(Icons.search),
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
              if (_mostrandoRecentes)
                Expanded(
                  // O voltar do Android fecha o painel em vez de sair do app.
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (_, _) => _focoBusca.unfocus(),
                    child: TapRegion(
                      groupId: _grupoBusca,
                      child: _BuscasRecentes(
                        recentes: _recentes.recentes,
                        onUsar: _usarRecente,
                        onRemover: _recentes.remover,
                        onLimpar: _recentes.limpar,
                      ),
                    ),
                  ),
                )
              else ...[
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
                      favoritos: widget.favoritos,
                      onAbrir: _abrir,
                      onLimparFiltros: _limparFiltros,
                    ),
                  ),
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}

/// As últimas buscas, da mais recente para a mais antiga: tocar refaz a busca, o X
/// tira uma e "Limpar" tira todas.
class _BuscasRecentes extends StatelessWidget {
  const _BuscasRecentes({
    required this.recentes,
    required this.onUsar,
    required this.onRemover,
    required this.onLimpar,
  });

  final List<String> recentes;
  final ValueChanged<String> onUsar;
  final ValueChanged<String> onRemover;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Buscas recentes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(onPressed: onLimpar, child: const Text('Limpar')),
            ],
          ),
        ),
        for (final termo in recentes)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(termo),
            onTap: () => onUsar(termo),
            trailing: IconButton(
              tooltip: 'Remover "$termo" das buscas recentes',
              icon: const Icon(Icons.close),
              onPressed: () => onRemover(termo),
            ),
          ),
      ],
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
    required this.favoritos,
    required this.onAbrir,
    required this.onLimparFiltros,
  });

  final List<Barbearia> barbearias;

  /// Lista vazia por causa da busca ou do filtro, e não porque o back-end está vazio.
  final bool filtrando;
  final FavoritosController favoritos;
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
        favoritos: favoritos,
        onTap: () => onAbrir(barbearias[i]),
      ),
    );
  }
}
