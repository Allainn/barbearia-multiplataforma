import 'package:barberhub_app/data/buscas_recentes_repository.dart';
import 'package:barberhub_app/state/buscas_recentes_controller.dart';
import 'package:barberhub_app/ui/widgets/barbearia_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dados.dart';
import 'support/pump_app.dart';

Future<BuscasRecentesController> _controller([
  Map<String, Object> salvo = const {},
]) async {
  SharedPreferences.setMockInitialValues(salvo);
  return BuscasRecentesController(
    BuscasRecentesRepository(await SharedPreferences.getInstance()),
  );
}

/// O painel de recentes, para não confundir com o texto dentro do campo de busca.
Finder _naListaDeRecentes(String termo) => find.widgetWithText(ListTile, termo);

void main() {
  group('registrarBusca', () {
    test('a busca nova vai para o topo', () {
      expect(registrarBusca(['bigode'], 'navalha'), ['navalha', 'bigode']);
    });

    test('repetida sobe para o topo, escrita como da última vez', () {
      expect(registrarBusca(['bigode', 'navalha'], 'NAVÁLHA'), [
        'NAVÁLHA',
        'bigode',
      ]);
    });

    test('tira espaço sobrando e ignora busca vazia', () {
      expect(registrarBusca([], '  dom   bigode '), ['dom bigode']);
      expect(registrarBusca(['bigode'], '   '), ['bigode']);
    });

    test('guarda no máximo as cinco mais recentes', () {
      final cheia = ['e', 'd', 'c', 'b', 'a'];
      expect(registrarBusca(cheia, 'f'), ['f', 'e', 'd', 'c', 'b']);
    });
  });

  group('BuscasRecentesController', () {
    test('as buscas continuam lá depois de fechar e abrir o app', () async {
      final antes = await _controller();
      await antes.registrar('navalha');
      await antes.registrar('bigode');

      // "abrir de novo": outro controller lendo o mesmo armazenamento
      final depois = BuscasRecentesController(
        BuscasRecentesRepository(await SharedPreferences.getInstance()),
      );
      expect(depois.recentes, ['bigode', 'navalha']);
    });

    test('remover tira uma; limpar tira todas; ambos avisam a tela', () async {
      final recentes = await _controller({
        BuscasRecentesRepository.storageKey: ['bigode', 'navalha', 'centro'],
      });
      var avisos = 0;
      recentes.addListener(() => avisos++);

      await recentes.remover('navalha');
      expect(recentes.recentes, ['bigode', 'centro']);

      await recentes.limpar();
      expect(recentes.recentes, isEmpty);
      expect(avisos, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(BuscasRecentesRepository.storageKey), isEmpty);
    });

    test(
      'registrar a mesma busca que já está no topo não avisa a tela',
      () async {
        final recentes = await _controller({
          BuscasRecentesRepository.storageKey: ['navalha'],
        });
        var avisos = 0;
        recentes.addListener(() => avisos++);

        await recentes.registrar('navalha');
        await recentes.registrar('');
        expect(avisos, 0);
      },
    );
  });

  group('buscas recentes na aba Barbearias', () {
    testWidgets(
      'tocar no campo mostra as recentes, e tocar numa refaz a busca',
      (tester) async {
        await pumpApp(
          tester,
          backendComBarbearias(),
          prefs: {
            BuscasRecentesRepository.storageKey: ['navalha', 'bigode'],
          },
        );
        await entrarComo(tester, 'cliente1', 'cliente123');
        expect(find.text('Buscas recentes'), findsNothing);
        expect(find.byType(BarbeariaCard), findsNWidgets(4));

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.text('Buscas recentes'), findsOneWidget);
        expect(_naListaDeRecentes('navalha'), findsOneWidget);
        expect(_naListaDeRecentes('bigode'), findsOneWidget);

        await tester.tap(_naListaDeRecentes('bigode'));
        await tester.pumpAndSettle();
        expect(find.text('Buscas recentes'), findsNothing);
        expect(find.byType(BarbeariaCard), findsOneWidget);
        expect(find.text('Dom Bigode'), findsOneWidget);
      },
    );

    testWidgets('confirmar a busca no teclado guarda; o X tira da lista', (
      tester,
    ) async {
      final deps = await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.enterText(find.byType(TextField), 'ouro');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(deps.buscasRecentes.recentes, ['ouro']);

      await tester.tap(find.byTooltip('Limpar a busca'));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(_naListaDeRecentes('ouro'), findsOneWidget);

      await tester.tap(find.byTooltip('Remover "ouro" das buscas recentes'));
      await tester.pumpAndSettle();
      // Sem recentes, o painel some e a lista volta.
      expect(find.text('Buscas recentes'), findsNothing);
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
    });

    testWidgets('a seta fecha o painel e volta para a lista', (tester) async {
      await pumpApp(
        tester,
        backendComBarbearias(),
        prefs: {
          BuscasRecentesRepository.storageKey: ['navalha'],
        },
      );
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Buscas recentes'), findsOneWidget);

      await tester.tap(find.byTooltip('Fechar buscas recentes'));
      await tester.pumpAndSettle();
      expect(find.text('Buscas recentes'), findsNothing);
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
    });
  });
}
