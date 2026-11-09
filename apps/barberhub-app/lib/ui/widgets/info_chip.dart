import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta pequena e não clicável: duração, preço, bairro. Para filtro clicável,
/// use o `FilterChip` do Material, que já segue o tema.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final IconData? icon;

  /// Destaque em latão (tertiary), ex.: o preço.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fundo = highlight
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final texto = highlight
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: texto),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: texto),
          ),
        ],
      ),
    );
  }
}
