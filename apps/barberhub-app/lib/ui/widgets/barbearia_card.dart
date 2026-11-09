import 'package:flutter/material.dart';

import '../../data/models/barbearia.dart';
import '../theme/app_theme.dart';
import 'monogram.dart';

/// Cartão de barbearia das listas (aba Barbearias e Favoritos), como no Guia visual.
class BarbeariaCard extends StatelessWidget {
  const BarbeariaCard({super.key, required this.barbearia, this.onTap});

  final Barbearia barbearia;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Monogram(nome: barbearia.nome),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(barbearia.nome, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      barbearia.endereco,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
