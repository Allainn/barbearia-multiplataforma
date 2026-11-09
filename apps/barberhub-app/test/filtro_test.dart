import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/state/async_state.dart';
import 'package:barberhub_app/state/filtro_barbearias.dart';
import 'package:barberhub_app/ui/widgets/barbearia_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dados.dart';
import 'support/fake_backend.dart';
import 'support/pump_app.dart';

final _todas = [for (final b in barbearias) Barbearia.fromJson(b)];

List<String> _nomes(List<Barbearia> lista) => [for (final b in lista) b.nome];

Barbearia _em(String endereco) =>
    Barbearia(id: endereco, nome: 'Teste', endereco: endereco);

void main() {
  group('bairro tirado do endereço', () {
    test('formato do seed: "Rua, número - Bairro"', () {
      final b = _em('Av. Getúlio Vargas, 1420 - Savassi');
      expect(b.bairro, 'Savassi');
      expect(b.logradouro, 'Av. Getúlio Vargas, 1420');
    });

    test('ignora a cidade depois do bairro e o hífen sem espaços da rua', () {
      expect(_em('Rua Pium-í, 611 - Sion, Belo Horizonte').bairro, 'Sion');
      expect(_em('Rua Pium-í, 611').bairro, isNull);
    });

    test('endereço fora do formato não tem bairro e aparece inteiro', () {
      final b = _em('Rua da Bahia 1000');
      expect(b.bairro, isNull);
      expect(b.logradouro, 'Rua da Bahia 1000');
      expect(_em('Rua X, 1 - ').bairro, isNull);
    });
  });

  group('bairrosDe', () {
    test('sem repetição, em ordem alfabética, com Outros por último', () {
      expect(bairrosDe(_todas), ['Lourdes', 'Savassi', 'Outros']);
    });

    test('com um bairro só não há o que filtrar', () {
      expect(
        bairrosDe([_em('Rua A, 1 - Centro'), _em('Rua B, 2 - Centro')]),
        isEmpty,
      );
      expect(bairrosDe([_em('Rua A 1')]), isEmpty);
      expect(bairrosDe(const []), isEmpty);
    });
  });

  group('filtrarBarbearias com bairro', () {
    test('mostra só as do bairro escolhido', () {
      expect(_nomes(filtrarBarbearias(_todas, bairro: 'Savassi')), [
        'Navalha de Ouro',
        'Savassi Clássica',
      ]);
    });

    test('Outros reúne as que não dizem o bairro', () {
      expect(_nomes(filtrarBarbearias(_todas, bairro: semBairro)), [
        'Barbearia Centro',
      ]);
    });

    test('combina com a busca por nome', () {
      expect(
        _nomes(filtrarBarbearias(_todas, busca: 'ouro', bairro: 'Savassi')),
        ['Navalha de Ouro'],
      );
      expect(
        filtrarBarbearias(_todas, busca: 'bigode', bairro: 'Savassi'),
        isEmpty,
      );
    });
  });

  test('bairro que some da lista recarregada deixa de filtrar', () async {
    final backend = backendComBarbearias();
    final deps = await criarDependencias(backend);
    await deps.auth.entrar('cliente1', 'cliente123');
    await deps.barbearias.carregar();
    deps.barbearias.filtrarPorBairro('Lourdes');
    expect(_nomes(deps.barbearias.visiveis), ['Dom Bigode']);

    backend.rotas['GET /barbearias'] = (_) =>
        jsonResponse([navalhaDeOuro, barbeariaCentro]);
    await deps.barbearias.carregar(silencioso: true);

    expect(deps.barbearias.estado, isA<AsyncData>());
    expect(deps.barbearias.bairro, isNull);
    expect(deps.barbearias.visiveis, hasLength(2));
  });

  group('filtro na aba Barbearias', () {
    testWidgets('tocar num bairro filtra; tocar de novo mostra todas', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');
      expect(find.byType(FilterChip), findsNWidgets(3));

      await tester.tap(find.widgetWithText(FilterChip, 'Savassi'));
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsNWidgets(2));
      expect(find.text('Dom Bigode'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Savassi'));
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
    });

    testWidgets('busca e bairro juntos sem resultado: limpar desfaz os dois', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.widgetWithText(FilterChip, 'Lourdes'));
      await tester.enterText(find.byType(TextField), 'navalha');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma barbearia encontrada'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Lourdes'))
            .selected,
        isFalse,
      );
    });
  });
}
