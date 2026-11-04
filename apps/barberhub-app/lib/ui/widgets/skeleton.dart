// Carregamento com a forma do conteúdo (skeleton + brilho), no lugar do spinner solto.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Brilho que passa por cima dos [SkeletonBox] filhos.
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Carregando',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Shimmer.fromColors(
          baseColor: scheme.surfaceContainerHighest,
          highlightColor: scheme.surfaceContainerLow,
          child: child,
        ),
      ),
    );
  }
}

/// Retângulo cinza no lugar de um texto ou imagem que ainda não chegou.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      // a cor real vem do Shimmer; precisa ser opaca para ele pintar por cima
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Lista de cartões em carregamento, com o mesmo desenho do cartão de barbearia.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        SkeletonBox(width: 48, height: 48, radius: AppRadius.md),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}
