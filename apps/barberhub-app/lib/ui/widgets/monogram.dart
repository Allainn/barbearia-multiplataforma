import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Iniciais num quadrado colorido, no lugar da foto que o contrato não tem
/// (barbearia, profissional). O mesmo nome sempre ganha a mesma cor.
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.nome, this.size = 48});

  final String nome;
  final double size;

  /// "Barbearia Centro" → "BC"; "Carlos" → "C". Ignora "da", "de", "do"...
  static String iniciais(String nome) {
    const ignorar = {'da', 'das', 'de', 'do', 'dos', 'e'};
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !ignorar.contains(p.toLowerCase()))
        .toList();
    if (partes.isEmpty) return '?';
    final letras = partes.length == 1
        ? partes.first.characters.first
        : partes.first.characters.first + partes.last.characters.first;
    return letras.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pares = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    // hash estável entre execuções (String.hashCode pode mudar entre plataformas)
    final indice = nome.codeUnits.fold(0, (soma, c) => soma + c) % pares.length;
    final (fundo, texto) = pares[indice];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(size * AppRadius.md / 48),
        ),
        child: Text(
          iniciais(nome),
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: size * 0.42,
            color: texto,
            height: 1,
          ),
        ),
      ),
    );
  }
}
