import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../../state/favoritos_controller.dart';

/// Coração de favoritar, em latão quando marcado. Escuta o controller sozinho.
class FavoritoButton extends StatelessWidget {
  const FavoritoButton({
    super.key,
    required this.barbearia,
    required this.favoritos,
  });

  final Barbearia barbearia;
  final FavoritosController favoritos;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favoritos,
      builder: (context, _) {
        final favorita = favoritos.ehFavorita(barbearia);
        return IconButton(
          tooltip: favorita ? 'Tirar dos favoritos' : 'Favoritar',
          isSelected: favorita,
          onPressed: () => favoritos.alternar(barbearia),
          icon: const Icon(Icons.favorite_outline),
          selectedIcon: Icon(
            Icons.favorite,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        );
      },
    );
  }
}
