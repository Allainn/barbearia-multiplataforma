import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../../state/favoritos_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/barbearia_card.dart';
import '../widgets/state_views.dart';

/// Aba "Favoritos": as barbearias marcadas com o coração, guardadas no aparelho.
///
/// Não tem estado de carregando nem de erro de rede: os dados já estão na memória
/// quando o app abre.
class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({
    super.key,
    required this.favoritos,
    required this.onAbrir,
    required this.onVerBarbearias,
  });

  final FavoritosController favoritos;
  final ValueChanged<Barbearia> onAbrir;

  /// Leva para a aba Barbearias quando ainda não há favoritas.
  final VoidCallback onVerBarbearias;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: ListenableBuilder(
        listenable: favoritos,
        builder: (context, _) {
          final favoritas = favoritos.favoritas;
          if (favoritas.isEmpty) {
            return EmptyView(
              icon: Icons.favorite_outline,
              title: 'Nenhuma favorita ainda',
              message:
                  'Toque no coração de uma barbearia para ela aparecer aqui, '
                  'mesmo depois de fechar o app.',
              action: FilledButton.tonal(
                onPressed: onVerBarbearias,
                child: const Text('Ver barbearias'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: favoritas.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => BarbeariaCard(
              barbearia: favoritas[i],
              favoritos: favoritos,
              onTap: () => onAbrir(favoritas[i]),
            ),
          );
        },
      ),
    );
  }
}
