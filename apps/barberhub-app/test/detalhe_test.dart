import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/state/async_state.dart';
import 'package:barberhub_app/state/barbearia_detalhe_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dados.dart';
import 'support/fake_backend.dart';
import 'support/pump_app.dart';

final _navalha = Barbearia.fromJson(navalhaDeOuro);

void main() {
  group('BarbeariaDetalheController', () {
    test(
      'junta profissionais e serviços, do serviço mais barato ao mais caro',
      () async {
        final deps = await criarDependencias(backendComBarbearias());
        await deps.auth.entrar('cliente1', 'cliente123');
        final controller = BarbeariaDetalheController(
          deps.barbeariaRepository,
          _navalha,
        );

        await controller.carregar();

        final detalhe =
            (controller.estado as AsyncData<DetalheBarbearia>).value;
        expect(
          [for (final p in detalhe.profissionais) p.nome],
          ['Bruno', 'Rafael'],
        );
        expect(
          [for (final s in detalhe.servicos) s.nome],
          ['Corte', 'Corte e barba'],
        );
        expect(detalhe.servicos.first.preco, 55.0);
        expect(detalhe.podeReservar, isTrue);
      },
    );

    test('se uma das duas chamadas falha, o estado é de erro', () async {
      final backend = backendComBarbearias();
      backend.rotas['GET /barbearias/${_navalha.id}/servicos'] = (_) =>
          jsonResponse({'detail': 'Serviço indisponível'}, 503);
      final deps = await criarDependencias(backend);
      await deps.auth.entrar('cliente1', 'cliente123');
      final controller = BarbeariaDetalheController(
        deps.barbeariaRepository,
        _navalha,
      );

      await controller.carregar();

      final erro = (controller.estado as AsyncError).error as ApiException;
      expect(erro.kind, ApiErrorKind.unavailable);
    });

    test('resposta que chega depois de a tela fechar é ignorada', () async {
      final deps = await criarDependencias(backendComBarbearias());
      await deps.auth.entrar('cliente1', 'cliente123');
      final controller = BarbeariaDetalheController(
        deps.barbeariaRepository,
        _navalha,
      );

      final carregando = controller.carregar();
      controller.dispose();

      await expectLater(carregando, completes);
    });
  });

  group('tela de detalhe', () {
    testWidgets('tocar num cartão abre serviços e profissionais', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.text('Navalha de Ouro'));
      await tester.pumpAndSettle();

      expect(find.text('Serviços'), findsOneWidget);
      expect(find.text('Corte e barba'), findsOneWidget);
      expect(find.text('1 h'), findsOneWidget);
      expect(find.text('R\$ 85,00'), findsOneWidget);
      expect(find.text('Profissionais'), findsOneWidget);
      expect(find.text('Rafael'), findsOneWidget);
    });

    testWidgets('barbearia que sumiu do servidor mostra "Não encontrado"', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      // O back-end falso só conhece o detalhe da Navalha de Ouro: as outras dão 404.
      await tester.tap(find.text('Dom Bigode'));
      await tester.pumpAndSettle();

      expect(find.text('Não encontrado'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
