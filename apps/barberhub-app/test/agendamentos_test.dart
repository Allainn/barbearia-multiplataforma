import 'dart:convert';

import 'package:barberhub_app/app_dependencies.dart';
import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/models/agendamento.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/data/models/disponibilidade.dart';
import 'package:barberhub_app/data/models/profissional.dart';
import 'package:barberhub_app/data/models/reserva_local.dart';
import 'package:barberhub_app/data/models/servico.dart';
import 'package:barberhub_app/data/reservas_local_repository.dart';
import 'package:barberhub_app/state/async_state.dart';
import 'package:barberhub_app/state/reserva_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dados.dart';
import 'support/fake_backend.dart';
import 'support/pump_app.dart';

/// Segunda, 09/11/2026, 12:00 na barbearia.
final _agora = DateTime.parse('2026-11-09T12:00:00-03:00');

ReservaLocal _reserva(
  String id, {
  required String inicio,
  String cliente = 'id-cliente1',
  StatusAgendamento status = StatusAgendamento.confirmado,
}) {
  final comeco = DateTime.parse(inicio);
  return ReservaLocal(
    agendamento: Agendamento(
      id: id,
      barbeariaId: navalhaDeOuro['id']!,
      profissionalId: rafael['id']!,
      servicoId: corte['id']! as String,
      clienteId: cliente,
      inicio: comeco,
      fim: comeco.add(const Duration(minutes: 30)),
      status: status,
    ),
    barbeariaNome: 'Navalha de Ouro',
    profissionalNome: 'Rafael',
    servicoNome: 'Corte',
    preco: 55,
  );
}

Future<AppDependencies> _logado(FakeBackend backend) async {
  final deps = await criarDependencias(backend);
  await deps.auth.entrar('cliente1', 'cliente123');
  return deps;
}

List<String> _ids(List<ReservaLocal> reservas) => [
  for (final r in reservas) r.id,
];

void main() {
  group('AgendamentosController', () {
    test(
      'separa próximos de histórico e mostra só os da conta logada',
      () async {
        final deps = await _logado(FakeBackend());
        final ag = deps.agendamentos;
        await ag.registrar(
          _reserva('depois', inicio: '2026-11-11T10:00:00-03:00'),
        );
        await ag.registrar(
          _reserva('amanha', inicio: '2026-11-10T10:00:00-03:00'),
        );
        await ag.registrar(
          _reserva('ontem', inicio: '2026-11-08T10:00:00-03:00'),
        );
        await ag.registrar(
          _reserva(
            'cancelada',
            inicio: '2026-11-12T10:00:00-03:00',
            status: StatusAgendamento.cancelado,
          ),
        );
        await ag.registrar(
          _reserva(
            'do-outro',
            inicio: '2026-11-10T11:00:00-03:00',
            cliente: 'id-cliente2',
          ),
        );
        // começou 11:45 e ainda não terminou: continua em "próximos"
        await ag.registrar(
          _reserva('em-curso', inicio: '2026-11-09T11:45:00-03:00'),
        );

        expect(_ids(ag.proximas('id-cliente1', _agora)), [
          'em-curso',
          'amanha',
          'depois',
        ]);
        expect(_ids(ag.historico('id-cliente1', _agora)), [
          'cancelada',
          'ontem',
        ]);
        expect(_ids(ag.proximas('id-cliente2', _agora)), ['do-outro']);
      },
    );

    test(
      'a reserva confirmada pelo back-end vai para o aparelho com os nomes da tela',
      () async {
        final deps = await _logado(backendComBarbearias());
        final controller = ReservaController(
          barbearia: Barbearia.fromJson(navalhaDeOuro),
          profissionais: [Profissional.fromJson(rafael)],
          servicos: [Servico.fromJson(corteEBarba)],
          disponibilidade: deps.disponibilidadeRepository,
          agendamentos: deps.agendamentoRepository,
          registro: deps.agendamentos,
          agora: () => _agora,
        );
        await controller.iniciar();
        controller.escolherHorario(
          (controller.horarios as AsyncData<List<HorarioLivre>>).value.first,
        );

        await controller.reservar();

        // outro controller lendo o mesmo armazenamento: "fechou e abriu o app"
        final salvo = ReservasLocalRepository(
          await SharedPreferences.getInstance(),
        ).ler();
        expect(salvo.single.id, 'ag-1');
        expect(salvo.single.barbeariaNome, 'Navalha de Ouro');
        expect(salvo.single.servicoNome, 'Corte e barba');
        expect(salvo.single.profissionalNome, 'Rafael');
        expect(salvo.single.preco, 85.0);
        expect(salvo.single.agendamento.clienteId, 'id-cliente1');
      },
    );

    test(
      'uma reserva ilegível no aparelho fica de fora sem apagar as outras',
      () async {
        final valida = _reserva('valida', inicio: '2026-11-10T10:00:00-03:00');
        // status que esta versão do app não conhece (ex.: o back-end ganhou um novo)
        final desconhecida = {
          ..._reserva('futura', inicio: '2026-11-11T10:00:00-03:00').toJson(),
        };
        desconhecida['agendamento'] = {
          ...(desconhecida['agendamento'] as Map<String, dynamic>),
          'status': 'CONCLUIDO',
        };
        final deps = await criarDependencias(
          FakeBackend(),
          prefs: {
            ReservasLocalRepository.storageKey: jsonEncode([
              valida.toJson(),
              desconhecida,
            ]),
          },
        );

        expect(_ids(deps.agendamentos.proximas('id-cliente1', _agora)), [
          'valida',
        ]);

        await deps.agendamentos.registrar(
          _reserva('nova', inicio: '2026-11-12T10:00:00-03:00'),
        );

        final prefs = await SharedPreferences.getInstance();
        final salvo =
            jsonDecode(prefs.getString(ReservasLocalRepository.storageKey)!)
                as List;
        expect(
          [for (final r in salvo) r['agendamento']['id']],
          ['valida', 'nova', 'futura'],
        );
        expect(salvo.last['agendamento']['status'], 'CONCLUIDO');
      },
    );

    test('409 não guarda nada no aparelho', () async {
      final backend = backendComBarbearias();
      backend.rotas['POST /agendamentos'] = (_) => jsonResponse({
        'detail': 'Horário indisponível para este profissional',
      }, 409);
      final deps = await _logado(backend);
      final controller = ReservaController(
        barbearia: Barbearia.fromJson(navalhaDeOuro),
        profissionais: [Profissional.fromJson(rafael)],
        servicos: [Servico.fromJson(corte)],
        disponibilidade: deps.disponibilidadeRepository,
        agendamentos: deps.agendamentoRepository,
        registro: deps.agendamentos,
        agora: () => _agora,
      );
      await controller.iniciar();
      controller.escolherHorario(
        (controller.horarios as AsyncData<List<HorarioLivre>>).value.first,
      );

      await controller.reservar();

      expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
    });

    test('cancelar chama o DELETE e a reserva vai para o histórico', () async {
      final backend = FakeBackend(
        rotas: {'DELETE /agendamentos/ag-1': (_) => http.Response('', 204)},
      );
      final deps = await _logado(backend);
      final reserva = _reserva('ag-1', inicio: '2026-11-10T10:00:00-03:00');
      await deps.agendamentos.registrar(reserva);

      final cancelamento = deps.agendamentos.cancelar(reserva);
      expect(deps.agendamentos.cancelando(reserva), isTrue);
      await cancelamento;

      expect(deps.agendamentos.cancelando(reserva), isFalse);
      expect(backend.chamadas('DELETE /agendamentos/ag-1'), hasLength(1));
      expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
      expect(
        deps.agendamentos.historico('id-cliente1', _agora).single.cancelada,
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      final salvo =
          jsonDecode(prefs.getString(ReservasLocalRepository.storageKey)!)
              as List;
      expect(salvo.single['agendamento']['status'], 'CANCELADO');
    });

    test(
      '404 no cancelamento: a reserva não existe mais no servidor e sai dos próximos',
      () async {
        final deps = await _logado(FakeBackend()); // sem a rota: 404
        final reserva = _reserva('sumiu', inicio: '2026-11-10T10:00:00-03:00');
        await deps.agendamentos.registrar(reserva);

        await deps.agendamentos.cancelar(reserva);

        expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
      },
    );

    test(
      'serviço fora do ar: o erro sobe e a reserva continua confirmada',
      () async {
        final backend = FakeBackend(
          rotas: {
            'DELETE /agendamentos/ag-1': (_) =>
                jsonResponse({'detail': 'Serviço indisponível'}, 503),
          },
        );
        final deps = await _logado(backend);
        final reserva = _reserva('ag-1', inicio: '2026-11-10T10:00:00-03:00');
        await deps.agendamentos.registrar(reserva);

        await expectLater(
          deps.agendamentos.cancelar(reserva),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.unavailable,
            ),
          ),
        );

        expect(_ids(deps.agendamentos.proximas('id-cliente1', _agora)), [
          'ag-1',
        ]);
        expect(deps.agendamentos.cancelando(reserva), isFalse);
      },
    );
  });

  group('aba Agendamentos', () {
    testWidgets('vazia, explica e leva para as barbearias', (tester) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'cliente1', 'cliente123');

      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum agendamento'), findsOneWidget);

      await tester.tap(find.text('Ver barbearias').hitTestable());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Barbearias'), findsOneWidget);
    });

    testWidgets('reservar, ver na aba e cancelar', (tester) async {
      final backend = backendComBarbearias();
      backend.rotas['DELETE /agendamentos/ag-1'] = (_) =>
          http.Response('', 204);
      await pumpApp(tester, backend);
      await entrarComo(tester, 'cliente1', 'cliente123');

      // reserva amanhã às 10:00
      await tester.tap(find.text('Navalha de Ouro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reservar horário'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Amanhã'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();
      expect(find.text('Próximos'), findsOneWidget);
      expect(find.text('Corte com Bruno'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.textContaining('10:00–10:30'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar esta reserva?'), findsOneWidget);
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();

      expect(backend.chamadas('DELETE /agendamentos/ag-1'), hasLength(1));
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsNothing);
      expect(find.text('Reserva cancelada.'), findsOneWidget);
    });

    testWidgets('"Manter" no diálogo não cancela', (tester) async {
      final backend = backendComBarbearias();
      final deps = await pumpApp(tester, backend);
      await deps.agendamentos.registrar(
        _reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
      );
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manter'));
      await tester.pumpAndSettle();

      expect(backend.chamadas('DELETE /agendamentos/ag-9'), isEmpty);
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('falha ao cancelar avisa e mantém a reserva', (tester) async {
      final backend = backendComBarbearias();
      backend.rotas['DELETE /agendamentos/ag-9'] = (_) =>
          jsonResponse({'detail': 'Serviço indisponível'}, 503);
      final deps = await pumpApp(tester, backend);
      await deps.agendamentos.registrar(
        _reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
      );
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível cancelar. Serviço indisponível'),
        findsOneWidget,
      );
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets(
      'outra conta no mesmo aparelho não vê as reservas do cliente1',
      (tester) async {
        final deps = await pumpApp(tester, backendComBarbearias());
        await deps.agendamentos.registrar(
          _reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
        );
        await entrarComo(tester, 'cliente2', 'cliente123');

        await tester.tap(find.text('Agendamentos'));
        await tester.pumpAndSettle();

        expect(find.text('Nenhum agendamento'), findsOneWidget);
      },
    );
  });
}
