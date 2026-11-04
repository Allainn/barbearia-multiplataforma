import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/api_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/info_chip.dart';
import '../widgets/monogram.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

/// Catálogo do visual do app para o grupo: cores, fontes e componentes, com dados
/// fictícios. Ao montar uma tela, copie daqui em vez de inventar estilo novo.
class GuiaVisualScreen extends StatelessWidget {
  const GuiaVisualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    const margem = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(title: const Text('Guia visual')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          Padding(
            padding: margem,
            child: Text(
              'Cor vem do colorScheme, espaço de AppSpacing, raio de AppRadius. '
              'Dados abaixo são fictícios.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),

          const SectionHeader(title: 'Cores'),
          Padding(
            padding: margem,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Swatch('primary', scheme.primary, scheme.onPrimary),
                _Swatch(
                  'primaryContainer',
                  scheme.primaryContainer,
                  scheme.onPrimaryContainer,
                ),
                _Swatch(
                  'secondaryContainer',
                  scheme.secondaryContainer,
                  scheme.onSecondaryContainer,
                ),
                _Swatch('tertiary (latão)', scheme.tertiary, scheme.onTertiary),
                _Swatch(
                  'tertiaryContainer',
                  scheme.tertiaryContainer,
                  scheme.onTertiaryContainer,
                ),
                _Swatch(
                  'surfaceContainer',
                  scheme.surfaceContainerHighest,
                  scheme.onSurface,
                ),
                _Swatch('error', scheme.error, scheme.onError),
              ],
            ),
          ),

          const SectionHeader(title: 'Tipografia'),
          Padding(
            padding: margem,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Barbearia Centro', style: text.headlineMedium),
                Text(
                  'headlineMedium · DM Serif Display',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Profissionais', style: text.titleLarge),
                Text('titleLarge · Manrope 700', style: text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Rua da Bahia, 1000 · Centro, Belo Horizonte',
                  style: text.bodyLarge,
                ),
                Text('bodyLarge · Manrope 400', style: text.bodySmall),
              ],
            ),
          ),

          const SectionHeader(title: 'Cartão de lista'),
          Padding(
            padding: margem,
            child: Card(
              child: InkWell(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Monogram(nome: 'Barbearia Centro'),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barbearia Centro', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Rua da Bahia 1000',
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                InfoChip(
                                  icon: Icons.schedule,
                                  label: formatDuracao(30),
                                ),
                                InfoChip(
                                  label: formatPreco(40),
                                  highlight: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Favoritar',
                        onPressed: () {},
                        icon: Icon(Icons.favorite, color: scheme.tertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SectionHeader(title: 'Busca, filtro e horários'),
          const Padding(
            padding: margem,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar barbearia',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: margem,
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (i, bairro) in [
                  'Centro',
                  'Savassi',
                  'Pampulha',
                ].indexed)
                  FilterChip(
                    label: Text(bairro),
                    selected: i == 0,
                    onSelected: (_) {},
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: margem,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (i, hora) in [
                  '09:00',
                  '09:30',
                  '10:00',
                  '10:30',
                ].indexed)
                  ChoiceChip(
                    label: Text(hora),
                    selected: i == 1,
                    onSelected: (_) {},
                  ),
              ],
            ),
          ),

          const SectionHeader(title: 'Botões'),
          Padding(
            padding: margem,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Reservar')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Ver horários'),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
                TextButton(onPressed: () {}, child: const Text('Limpar')),
              ],
            ),
          ),

          const SectionHeader(title: 'Estados: carregando, vazio e erro'),
          Padding(
            padding: margem,
            child: Column(
              children: [
                const _Moldura(height: 190, child: SkeletonList(itemCount: 2)),
                const SizedBox(height: AppSpacing.sm),
                const _Moldura(
                  height: 270,
                  child: EmptyView(
                    icon: Icons.search_off,
                    title: 'Nenhuma barbearia encontrada',
                    message: 'Tente outro nome ou limpe os filtros.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Moldura(
                  height: 330,
                  child: ErrorView(
                    error: const ApiException.offline(),
                    onRetry: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.nome, this.cor, this.texto);

  final String nome;
  final Color cor;
  final Color texto;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    height: 56,
    padding: const EdgeInsets.all(AppSpacing.sm),
    alignment: Alignment.bottomLeft,
    decoration: BoxDecoration(
      color: cor,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Text(
      nome,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: texto),
    ),
  );
}

/// Caixa com borda e altura fixa, para mostrar um estado de tela inteira no guia.
class _Moldura extends StatelessWidget {
  const _Moldura({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Card(child: child),
  );
}
