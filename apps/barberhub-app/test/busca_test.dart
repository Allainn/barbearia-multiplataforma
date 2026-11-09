import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/state/filtro_barbearias.dart';
import 'package:barberhub_app/ui/widgets/barbearia_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dados.dart';
import 'support/pump_app.dart';

final _todas = [for (final b in barbearias) Barbearia.fromJson(b)];

List<String> _nomes(List<Barbearia> lista) => [for (final b in lista) b.nome];

void main() {
  group('filtrarBarbearias', () {
    test('busca vazia ou só com espaços devolve todas', () {
      expect(filtrarBarbearias(_todas), _todas);
      expect(filtrarBarbearias(_todas, busca: '   '), _todas);
    });

    test('acha pelo meio do nome, sem ligar para maiúsculas e acentos', () {
      expect(_nomes(filtrarBarbearias(_todas, busca: 'CLASSICA')), [
        'Savassi Clássica',
      ]);
      expect(_nomes(filtrarBarbearias(_todas, busca: 'bigóde')), [
        'Dom Bigode',
      ]);
    });

    test('procura no nome, não no endereço', () {
      // "Savassi" está no endereço da Navalha de Ouro, mas só no nome da Savassi Clássica
      expect(_nomes(filtrarBarbearias(_todas, busca: 'savassi')), [
        'Savassi Clássica',
      ]);
    });

    test('sem resultado devolve lista vazia', () {
      expect(filtrarBarbearias(_todas, busca: 'pizzaria'), isEmpty);
    });
  });

  test('normalizar tira acento, caixa e espaço sobrando', () {
    expect(normalizar('  São  José '), 'sao jose');
    expect(normalizar('Pium-í'), 'pium-i');
  });

  group('busca na aba Barbearias', () {
    testWidgets('digitar filtra a lista e o X traz todas de volta', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');
      expect(find.byType(BarbeariaCard), findsNWidgets(4));

      await tester.enterText(find.byType(TextField), 'navalha');
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsOneWidget);
      expect(find.text('Navalha de Ouro'), findsOneWidget);

      await tester.tap(find.byTooltip('Limpar a busca'));
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
    });

    testWidgets('busca sem resultado explica e oferece limpar', (tester) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.enterText(find.byType(TextField), 'pizzaria');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma barbearia encontrada'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
      expect(find.text('pizzaria'), findsNothing);
    });
  });
}
