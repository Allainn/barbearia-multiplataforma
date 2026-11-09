import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../../state/async_state.dart';
import '../../state/barbearias_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barbearia_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Aba "Barbearias": a lista que vem do `GET /barbearias`.
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
  BarbeariasController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // A aba nasce logo depois do login: é a hora de buscar com o token novo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.carregar());
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
          AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => _controller.carregar(silencioso: true),
            child: _Lista(barbearias: value, onAbrir: widget.onAbrir),
          ),
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.barbearias, required this.onAbrir});

  final List<Barbearia> barbearias;
  final ValueChanged<Barbearia> onAbrir;

  @override
  Widget build(BuildContext context) {
    if (barbearias.isEmpty) {
      // Dentro de uma lista rolável, para o "puxar para atualizar" funcionar no vazio.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const EmptyView(
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
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: barbearias.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => BarbeariaCard(
        barbearia: barbearias[i],
        onTap: () => onAbrir(barbearias[i]),
      ),
    );
  }
}
