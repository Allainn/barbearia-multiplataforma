import 'dart:convert';

import 'package:barberhub_app/data/favoritos_repository.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/state/favoritos_controller.dart';
import 'package:barberhub_app/ui/widgets/barbearia_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dados.dart';
import 'support/pump_app.dart';

final _navalha = Barbearia.fromJson(navalhaDeOuro);
final _bigode = Barbearia.fromJson(domBigode);

Future<FavoritosController> _controller([
  Map<String, Object> salvo = const {},
]) async {
  SharedPreferences.setMockInitialValues(salvo);
  return FavoritosController(
    FavoritosRepository(await SharedPreferences.getInstance()),
  );
}

void main() {
  group('FavoritosController', () {
    test(
      'começa vazio; marcar e desmarcar muda a lista e avisa a tela',
      () async {
        final favoritos = await _controller();
        var avisos = 0;
        favoritos.addListener(() => avisos++);
        expect(favoritos.favoritas, isEmpty);

        await favoritos.alternar(_navalha);
        await favoritos.alternar(_bigode);
        expect(favoritos.ehFavorita(_navalha), isTrue);
        expect(favoritos.favoritas, [
          _bigode,
          _navalha,
        ]); // a mais recente primeiro

        await favoritos.alternar(_navalha);
        expect(favoritos.ehFavorita(_navalha), isFalse);
        expect(favoritos.favoritas, [_bigode]);
        expect(avisos, 3);
      },
    );

    test(
      'o que foi marcado continua lá depois de fechar e abrir o app',
      () async {
        final antes = await _controller();
        await antes.alternar(_navalha);

        // "abrir de novo": outro controller lendo o mesmo armazenamento
        final depois = FavoritosController(
          FavoritosRepository(await SharedPreferences.getInstance()),
        );

        expect(depois.favoritas.single.nome, 'Navalha de Ouro');
        expect(depois.favoritas.single.endereco, _navalha.endereco);
      },
    );

    test(
      'dado corrompido no aparelho vira lista vazia, e dá para favoritar de novo',
      () async {
        final favoritos = await _controller({
          FavoritosRepository.storageKey: '{isto não é uma lista',
        });
        expect(favoritos.favoritas, isEmpty);

        await favoritos.alternar(_bigode);

        final prefs = await SharedPreferences.getInstance();
        final salvo = jsonDecode(
          prefs.getString(FavoritosRepository.storageKey)!,
        );
        expect(salvo, [domBigode]);
      },
    );
  });

  test(
    'favorito ilegível fica de fora, mas não some do aparelho ao favoritar outro',
    () async {
      final favoritos = await _controller({
        FavoritosRepository.storageKey: jsonEncode([
          navalhaDeOuro,
          {'id': 'sem-nome'},
        ]),
      });
      expect(favoritos.favoritas, [_navalha]);

      await favoritos.alternar(_bigode);

      final prefs = await SharedPreferences.getInstance();
      final salvo = jsonDecode(
        prefs.getString(FavoritosRepository.storageKey)!,
      );
      expect(salvo, [
        navalhaDeOuro,
        domBigode,
        {'id': 'sem-nome'},
      ]);
    },
  );

  group('favoritos nas telas', () {
    testWidgets('a aba começa vazia e leva para as barbearias', (tester) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma favorita ainda'), findsOneWidget);

      await tester.tap(find.text('Ver barbearias'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Barbearias'), findsOneWidget);
    });

    testWidgets('coração na lista põe a barbearia na aba Favoritos', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(BarbeariaCard, 'Dom Bigode'),
          matching: find.byTooltip('Favoritar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tirar dos favoritos'), findsOneWidget);

      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      // o IndexedStack mantém a aba Barbearias montada, fora da tela
      expect(
        find.widgetWithText(BarbeariaCard, 'Dom Bigode').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Nenhuma favorita ainda'), findsNothing);
    });

    testWidgets('coração no detalhe vale também na lista', (tester) async {
      final deps = await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.text('Navalha de Ouro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritar').hitTestable());
      await tester.pumpAndSettle();
      expect(deps.favoritos.ehFavorita(_navalha), isTrue);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(BarbeariaCard, 'Navalha de Ouro'),
          matching: find.byTooltip('Tirar dos favoritos'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'favoritas salvas aparecem ao abrir o app, antes de qualquer rede',
      (tester) async {
        await pumpApp(
          tester,
          backendComBarbearias(),
          prefs: {
            FavoritosRepository.storageKey: jsonEncode([savassiClassica]),
          },
        );
        await entrarComo(tester, 'cliente1', 'cliente123');

        await tester.tap(find.text('Favoritos'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(BarbeariaCard, 'Savassi Clássica').hitTestable(),
          findsOneWidget,
        );
      },
    );
  });
}
