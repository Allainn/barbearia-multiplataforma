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

/// Uma reserva como o aparelho guarda: o agendamento com os nomes da tela.
ReservaLocal _reserva(
  String id, {
  required String inicio,
  String cliente = 'id-cliente1',
  StatusAgendamento status = StatusAgendamento.confirmado,
}) => ReservaLocal(
  agendamento: Agendamento.fromJson(
    agendamentoJson(
      id,
      inicio: inicio,
      cliente: cliente,
      status: status.name.toUpperCase(),
    ),
  ),
  barbeariaNome: 'Navalha de Ouro',
  profissionalNome: 'Rafael',
  servicoNome: 'Corte',
  preco: 55,
);

/// O aparelho com [reservas] já guardadas, como se o app tivesse sido fechado e aberto.
Map<String, Object> _cache(List<ReservaLocal> reservas) => {
  ReservasLocalRepository.storageKey: jsonEncode([
    for (final r in reservas) r.toJson(),
  ]),
};

Future<AppDependencies> _logado(
  FakeBackend backend, {
  Map<String, Object> prefs = const {},
}) async {
  final deps = await criarDependencias(backend, prefs: prefs);
  await deps.auth.entrar('cliente1', 'cliente123');
  return deps;
}

List<String> _ids(List<ReservaLocal> reservas) => [
  for (final r in reservas) r.id,
];

Future<List<dynamic>> _salvo() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(ReservasLocalRepository.storageKey)!)
      as List;
}

void main() {
  group('AgendamentosController', () {
    test('servidor devolve [] -> estado vazio', () async {
      // o aparelho ainda lembra de uma reserva que não existe mais no servidor
      final deps = await _logado(
        backendComBarbearias(),
        prefs: _cache([
          _reserva('antiga', inicio: '2026-11-10T10:00:00-03:00'),
        ]),
      );

      await deps.agendamentos.carregar('id-cliente1');

      final estado = deps.agendamentos.estado('id-cliente1');
      expect(estado, isA<AsyncData<List<ReservaLocal>>>());
      expect((estado as AsyncData<List<ReservaLocal>>).value, isEmpty);
      expect(deps.agendamentos.desatualizado, isFalse);
      // o que sumiu do servidor sai também do cache
      expect(await _salvo(), isEmpty);
    });

    test(
      'agendamento só no servidor aparece com os nomes do catálogo, uma chamada '
      'por barbearia',
      () async {
        final servidor = AgendamentosNoServidor()
          ..itens.addAll([
            agendamentoJson(
              'de-outro-celular',
              inicio: '2026-11-10T10:00:00-03:00',
            ),
            agendamentoJson(
              'pelo-curl',
              inicio: '2026-11-11T15:00:00-03:00',
              profissionalId: bruno['id'],
              servicoId: corteEBarba['id'] as String,
            ),
          ]);
        final backend = backendComBarbearias(servidor: servidor);
        final deps = await _logado(backend);

        await deps.agendamentos.carregar('id-cliente1');

        final proximas = deps.agendamentos.proximas('id-cliente1', _agora);
        expect(_ids(proximas), ['de-outro-celular', 'pelo-curl']);
        expect(proximas[0].barbeariaNome, 'Navalha de Ouro');
        expect(proximas[0].profissionalNome, 'Rafael');
        expect(proximas[0].servicoNome, 'Corte');
        expect(proximas[0].preco, 55.0);
        expect(proximas[1].profissionalNome, 'Bruno');
        expect(proximas[1].servicoNome, 'Corte e barba');
        expect(proximas[1].preco, 85.0);
        final idNavalha = navalhaDeOuro['id'];
        expect(backend.chamadas('GET /barbearias'), hasLength(1));
        expect(
          backend.chamadas('GET /barbearias/$idNavalha/profissionais'),
          hasLength(1),
        );
        expect(
          backend.chamadas('GET /barbearias/$idNavalha/servicos'),
          hasLength(1),
        );

        // os nomes ficam no cache: a próxima carga não volta ao catálogo
        await deps.agendamentos.carregar('id-cliente1');
        expect(backend.chamadas('GET /barbearias'), hasLength(1));
      },
    );

    test(
      'cancelado no servidor e confirmado no cache -> aparece cancelado',
      () async {
        final servidor = AgendamentosNoServidor()
          ..itens.add(
            agendamentoJson(
              'ag-1',
              inicio: '2026-11-10T10:00:00-03:00',
              status: 'CANCELADO',
            ),
          );
        final backend = backendComBarbearias(servidor: servidor);
        final deps = await _logado(
          backend,
          prefs: _cache([
            _reserva('ag-1', inicio: '2026-11-10T10:00:00-03:00'),
          ]),
        );

        await deps.agendamentos.carregar('id-cliente1');

        expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
        final cancelada = deps.agendamentos
            .historico('id-cliente1', _agora)
            .single;
        expect(cancelada.cancelada, isTrue);
        // os nomes vieram do cache, sem ir ao catálogo
        expect(cancelada.barbeariaNome, 'Navalha de Ouro');
        expect(backend.chamadas('GET /barbearias'), isEmpty);
        expect((await _salvo()).single['agendamento']['status'], 'CANCELADO');
      },
    );

    test('falha de rede -> mostra o cache e sinaliza desatualizado', () async {
      final backend = backendComBarbearias();
      final deps = await _logado(
        backend,
        prefs: _cache([
          _reserva('ag-1', inicio: '2026-11-10T10:00:00-03:00'),
          _reserva(
            'de-outra-conta',
            inicio: '2026-11-10T11:00:00-03:00',
            cliente: 'id-cliente2',
          ),
        ]),
      );
      backend.semRede = true;

      await deps.agendamentos.carregar('id-cliente1');

      expect(deps.agendamentos.desatualizado, isTrue);
      expect(_ids(deps.agendamentos.proximas('id-cliente1', _agora)), ['ag-1']);

      // a rede volta: a lista passa a ser a do servidor, sem o aviso
      backend.semRede = false;
      await deps.agendamentos.carregar('id-cliente1', silencioso: true);
      expect(deps.agendamentos.desatualizado, isFalse);
      expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
    });

    test('sem rede e nada no aparelho: estado de erro', () async {
      final backend = backendComBarbearias();
      final deps = await _logado(backend);
      backend.semRede = true;

      await deps.agendamentos.carregar('id-cliente1');

      final estado = deps.agendamentos.estado('id-cliente1');
      expect(estado, isA<AsyncError<List<ReservaLocal>>>());
      expect(
        ((estado as AsyncError).error as ApiException).kind,
        ApiErrorKind.offline,
      );
    });

    test(
      'separa próximos de histórico e não mostra o cache de outra conta',
      () async {
        final servidor = AgendamentosNoServidor()
          ..itens.addAll([
            for (final (id, inicio, status) in [
              ('depois', '2026-11-11T10:00:00-03:00', 'CONFIRMADO'),
              ('amanha', '2026-11-10T10:00:00-03:00', 'CONFIRMADO'),
              ('ontem', '2026-11-08T10:00:00-03:00', 'CONFIRMADO'),
              ('cancelada', '2026-11-12T10:00:00-03:00', 'CANCELADO'),
              // começou 11:45 e ainda não terminou: continua em "próximos"
              ('em-curso', '2026-11-09T11:45:00-03:00', 'CONFIRMADO'),
            ])
              agendamentoJson(id, inicio: inicio, status: status),
          ]);
        final deps = await _logado(
          backendComBarbearias(servidor: servidor),
          prefs: _cache([
            _reserva(
              'do-outro',
              inicio: '2026-11-10T11:00:00-03:00',
              cliente: 'id-cliente2',
            ),
          ]),
        );
        final ag = deps.agendamentos;

        await ag.carregar('id-cliente1');

        expect(_ids(ag.proximas('id-cliente1', _agora)), [
          'em-curso',
          'amanha',
          'depois',
        ]);
        expect(_ids(ag.historico('id-cliente1', _agora)), [
          'cancelada',
          'ontem',
        ]);
        expect(ag.proximas('id-cliente2', _agora), isEmpty);
        // a reserva da outra conta continua guardada para quando ela entrar
        expect([
          for (final r in await _salvo()) r['agendamento']['id'],
        ], contains('do-outro'));
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
        final servidor = AgendamentosNoServidor()
          ..itens.add(valida.agendamento.toJson());
        final deps = await _logado(
          backendComBarbearias(servidor: servidor),
          prefs: {
            ReservasLocalRepository.storageKey: jsonEncode([
              valida.toJson(),
              desconhecida,
            ]),
          },
        );

        await deps.agendamentos.carregar('id-cliente1');
        expect(_ids(deps.agendamentos.proximas('id-cliente1', _agora)), [
          'valida',
        ]);

        await deps.agendamentos.registrar(
          _reserva('nova', inicio: '2026-11-12T10:00:00-03:00'),
        );

        final salvo = await _salvo();
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
      await deps.agendamentos.carregar('id-cliente1');
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

    test('cancelar chama o DELETE e a lista reflete o servidor', () async {
      final servidor = AgendamentosNoServidor()
        ..itens.add(
          agendamentoJson('ag-1', inicio: '2026-11-10T10:00:00-03:00'),
        );
      final backend = backendComBarbearias(servidor: servidor);
      backend.rotas['DELETE /agendamentos/ag-1'] = servidor.cancelar('ag-1');
      final deps = await _logado(backend);
      await deps.agendamentos.carregar('id-cliente1');
      final reserva = deps.agendamentos.proximas('id-cliente1', _agora).single;

      final cancelamento = deps.agendamentos.cancelar(reserva);
      expect(deps.agendamentos.cancelando(reserva), isTrue);
      await cancelamento;

      expect(deps.agendamentos.cancelando(reserva), isFalse);
      expect(backend.chamadas('DELETE /agendamentos/ag-1'), hasLength(1));
      // depois do DELETE, uma releitura do servidor
      expect(backend.chamadas('GET /agendamentos'), hasLength(2));
      expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
      expect(
        deps.agendamentos.historico('id-cliente1', _agora).single.cancelada,
        isTrue,
      );
      expect((await _salvo()).single['agendamento']['status'], 'CANCELADO');
    });

    test(
      '404 no cancelamento: a reserva não existe mais no servidor e sai da lista',
      () async {
        final servidor = AgendamentosNoServidor()
          ..itens.add(
            agendamentoJson('sumiu', inicio: '2026-11-10T10:00:00-03:00'),
          );
        final deps = await _logado(backendComBarbearias(servidor: servidor));
        await deps.agendamentos.carregar('id-cliente1');
        final reserva = deps.agendamentos
            .proximas('id-cliente1', _agora)
            .single;
        servidor.itens.clear(); // o ambiente de demo foi recriado

        await deps.agendamentos.cancelar(reserva); // sem a rota: 404

        expect(deps.agendamentos.proximas('id-cliente1', _agora), isEmpty);
        expect(deps.agendamentos.historico('id-cliente1', _agora), isEmpty);
      },
    );

    test(
      'serviço fora do ar: o erro sobe e a reserva continua confirmada',
      () async {
        final servidor = AgendamentosNoServidor()
          ..itens.add(
            agendamentoJson('ag-1', inicio: '2026-11-10T10:00:00-03:00'),
          );
        final backend = backendComBarbearias(servidor: servidor);
        backend.rotas['DELETE /agendamentos/ag-1'] = (_) =>
            jsonResponse({'detail': 'Serviço indisponível'}, 503);
        final deps = await _logado(backend);
        await deps.agendamentos.carregar('id-cliente1');
        final reserva = deps.agendamentos
            .proximas('id-cliente1', _agora)
            .single;

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
      final servidor = AgendamentosNoServidor();
      final backend = backendComBarbearias(servidor: servidor);
      backend.rotas['DELETE /agendamentos/ag-1'] = servidor.cancelar('ag-1');
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
      expect(servidor.itens.single['status'], 'CANCELADO');
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsNothing);
      expect(find.text('Reserva cancelada.'), findsOneWidget);
    });

    testWidgets('puxar para atualizar mostra o cancelamento feito por fora', (
      tester,
    ) async {
      final servidor = AgendamentosNoServidor()
        ..itens.add(
          agendamentoJson('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
        );
      await pumpApp(tester, backendComBarbearias(servidor: servidor));
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmada'), findsOneWidget);

      servidor.itens.single['status'] = 'CANCELADO'; // pelo curl, por exemplo
      await tester.fling(find.text('Próximos'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Confirmada'), findsNothing);
    });

    testWidgets('puxar sem rede mantém a lista e avisa', (tester) async {
      final backend = backendComBarbearias();
      await pumpApp(
        tester,
        backend,
        prefs: _cache([_reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00')]),
      );
      await entrarComo(tester, 'cliente1', 'cliente123');
      backend.semRede = true;
      // as abas já carregaram no login; puxar de novo, agora sem rede
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();
      await tester.fling(
        find.text('Nenhum agendamento'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhum agendamento'), findsOneWidget);
      expect(find.textContaining('podem estar desatualizadas'), findsOneWidget);
    });

    testWidgets('sem rede desde o login: o cache aparece com o aviso', (
      tester,
    ) async {
      final backend = backendComBarbearias();
      backend.rotas['GET /agendamentos'] = (_) =>
          throw http.ClientException('sem rede');
      await pumpApp(
        tester,
        backend,
        prefs: _cache([_reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00')]),
      );
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('Corte com Rafael'), findsOneWidget);
      expect(find.textContaining('podem estar desatualizadas'), findsOneWidget);
    });

    testWidgets('catálogo fora do ar: a reserva aparece com texto neutro', (
      tester,
    ) async {
      final servidor = AgendamentosNoServidor()
        ..itens.add(
          agendamentoJson('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
        );
      final backend = backendComBarbearias(servidor: servidor);
      final catalogo = {
        for (final rota in [
          'GET /barbearias',
          'GET /barbearias/${navalhaDeOuro['id']}/profissionais',
          'GET /barbearias/${navalhaDeOuro['id']}/servicos',
        ])
          rota: backend.rotas.remove(rota)!,
      };
      await pumpApp(tester, backend);
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Agendamentos'));
      await tester.pumpAndSettle();

      expect(find.text('Barbearia não identificada'), findsOneWidget);
      expect(find.text('Detalhes indisponíveis no momento'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);

      // o catálogo volta: puxar para atualizar tenta os nomes de novo
      backend.rotas.addAll(catalogo);
      await tester.fling(find.text('Próximos'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Navalha de Ouro'), findsOneWidget);
      expect(find.text('Corte com Rafael'), findsOneWidget);
    });

    testWidgets('"Manter" no diálogo não cancela', (tester) async {
      final servidor = AgendamentosNoServidor()
        ..itens.add(
          agendamentoJson('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
        );
      final backend = backendComBarbearias(servidor: servidor);
      await pumpApp(tester, backend);
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
      final servidor = AgendamentosNoServidor()
        ..itens.add(
          agendamentoJson('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
        );
      final backend = backendComBarbearias(servidor: servidor);
      backend.rotas['DELETE /agendamentos/ag-9'] = (_) =>
          jsonResponse({'detail': 'Serviço indisponível'}, 503);
      await pumpApp(tester, backend);
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
        await pumpApp(
          tester,
          backendComBarbearias(),
          prefs: _cache([
            _reserva('ag-9', inicio: '2099-01-05T10:00:00-03:00'),
          ]),
        );
        await entrarComo(tester, 'cliente2', 'cliente123');

        await tester.tap(find.text('Agendamentos'));
        await tester.pumpAndSettle();

        expect(find.text('Nenhum agendamento'), findsOneWidget);
      },
    );
  });
}
