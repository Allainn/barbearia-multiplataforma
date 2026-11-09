import 'dart:async';

import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/state/async_state.dart';
import 'package:barberhub_app/ui/widgets/barbearia_card.dart';
import 'package:barberhub_app/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/dados.dart';
import 'support/fake_backend.dart';
import 'support/pump_app.dart';

void main() {
  group('BarbeariasController', () {
    test('carrega do BFF com o token e ordena por nome', () async {
      final backend = backendComBarbearias();
      final deps = await criarDependencias(backend);
      await deps.auth.entrar('cliente1', 'cliente123');

      expect(deps.barbearias.estado, isA<AsyncLoading>());
      await deps.barbearias.carregar();

      final estado = deps.barbearias.estado as AsyncData;
      expect(
        [for (final b in estado.value) b.nome],
        [
          'Barbearia Centro',
          'Dom Bigode',
          'Navalha de Ouro',
          'Savassi Clássica',
        ],
      );
      final chamada = backend.chamadas('GET /barbearias').single;
      expect(
        chamada.headers['Authorization'],
        'Bearer ${deps.auth.sessao!.accessToken}',
      );
    });

    test(
      'falha do BFF vira estado de erro, e tentar de novo recupera',
      () async {
        var fora = true;
        final backend = FakeBackend(
          rotas: {
            'GET /barbearias': (_) => fora
                ? jsonResponse({'detail': 'Serviço indisponível'}, 503)
                : jsonResponse(barbearias),
          },
        );
        final deps = await criarDependencias(backend);
        await deps.auth.entrar('cliente1', 'cliente123');

        await deps.barbearias.carregar();
        final erro =
            (deps.barbearias.estado as AsyncError).error as ApiException;
        expect(erro.kind, ApiErrorKind.unavailable);

        fora = false;
        await deps.barbearias.carregar();
        expect(deps.barbearias.estado, isA<AsyncData>());
      },
    );

    test(
      'resposta atrasada não passa por cima de um pedido mais novo',
      () async {
        final respostas = [
          Completer<http.Response>(),
          Completer<http.Response>(),
        ];
        var pedidos = 0;
        final backend = FakeBackend(
          rotas: {'GET /barbearias': (_) => respostas[pedidos++].future},
        );
        final deps = await criarDependencias(backend);
        await deps.auth.entrar('cliente1', 'cliente123');

        final primeiro = deps.barbearias.carregar();
        final segundo = deps.barbearias.carregar();
        respostas[1].complete(jsonResponse([domBigode]));
        await segundo;
        respostas[0].complete(jsonResponse(barbearias));
        await primeiro;

        final estado = deps.barbearias.estado as AsyncData;
        expect(estado.value, hasLength(1));
      },
    );
  });

  group('aba Barbearias', () {
    testWidgets('mostra o skeleton e depois os cartões', (tester) async {
      final resposta = Completer<http.Response>();
      final backend = FakeBackend(
        rotas: {'GET /barbearias': (_) => resposta.future},
      );
      await pumpApp(tester, backend);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuário'),
        'cliente1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'cliente123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      // o shimmer anima para sempre: avança um pouco em vez de pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SkeletonList), findsOneWidget);

      resposta.complete(jsonResponse(barbearias));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonList), findsNothing);
      expect(find.byType(BarbeariaCard), findsNWidgets(4));
      expect(find.text('Av. Getúlio Vargas, 1420'), findsOneWidget);
      expect(find.text('Rua da Bahia 1000'), findsOneWidget);
    });

    testWidgets('sem rede mostra o erro com o botão de tentar de novo', (
      tester,
    ) async {
      final backend = backendComBarbearias();
      await pumpApp(tester, backend);
      backend.rotas['GET /barbearias'] = (request) =>
          throw http.ClientException('sem rede', request.url);
      await entrarComo(tester, 'cliente1', 'cliente123');

      expect(find.text('Sem conexão'), findsOneWidget);

      backend.rotas['GET /barbearias'] = (_) => jsonResponse(barbearias);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.byType(BarbeariaCard), findsNWidgets(4));
    });

    testWidgets('lista vazia explica em vez de mostrar tela branca', (
      tester,
    ) async {
      final backend = FakeBackend(
        rotas: {'GET /barbearias': (_) => jsonResponse([])},
      );
      await pumpApp(tester, backend);
      await entrarComo(tester, 'cliente1', 'cliente123');

      expect(find.text('Nenhuma barbearia cadastrada'), findsOneWidget);
    });
  });
}
