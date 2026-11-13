import 'dart:convert';

import 'package:barberhub_app/app_dependencies.dart';
import 'package:barberhub_app/core/formatters.dart';
import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/catalogo_nomes.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/data/models/disponibilidade.dart';
import 'package:barberhub_app/data/models/profissional.dart';
import 'package:barberhub_app/data/models/reserva_local.dart';
import 'package:barberhub_app/data/models/servico.dart';
import 'package:barberhub_app/data/reservas_local_repository.dart';
import 'package:barberhub_app/state/agendamentos_controller.dart';
import 'package:barberhub_app/state/async_state.dart';
import 'package:barberhub_app/state/reserva_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dados.dart';
import 'support/fake_backend.dart';
import 'support/pump_app.dart';

final _navalha = Barbearia.fromJson(navalhaDeOuro);
final _corte = Servico.fromJson(corte);
final _corteEBarba = Servico.fromJson(corteEBarba);
final _rafael = Profissional.fromJson(rafael);
final _bruno = Profissional.fromJson(bruno);

/// Segunda, 09/11/2026, 08:00 na barbearia: antes de abrir.
final _manha = DateTime.parse('2026-11-09T08:00:00-03:00');

ReservaController _controller(AppDependencies deps, {DateTime? agora}) =>
    ReservaController(
      barbearia: _navalha,
      profissionais: [_bruno, _rafael],
      servicos: [_corte, _corteEBarba],
      disponibilidade: deps.disponibilidadeRepository,
      agendamentos: deps.agendamentoRepository,
      agora: () => agora ?? _manha,
    );

List<String> _horas(ReservaController c) => [
  for (final h in (c.horarios as AsyncData<List<HorarioLivre>>).value)
    formatHora(h.inicio),
];

HorarioLivre _as(ReservaController c, String hora) =>
    (c.horarios as AsyncData<List<HorarioLivre>>).value.firstWhere(
      (h) => formatHora(h.inicio) == hora,
    );

/// Armazenamento que falha ao gravar (aparelho sem espaço, por exemplo).
class _LocalQueNaoGrava extends ReservasLocalRepository {
  _LocalQueNaoGrava(super.prefs);

  @override
  Future<void> salvar(List<ReservaLocal> reservas) =>
      Future.error(Exception('sem espaço no aparelho'));
}

Future<AppDependencies> _logado(
  FakeBackend backend, [
  String usuario = 'cliente1',
]) async {
  final deps = await criarDependencias(backend);
  await deps.auth.entrar(
    usuario,
    usuario == 'gestor1' ? 'gestor123' : 'cliente123',
  );
  return deps;
}

void main() {
  group('ReservaController', () {
    test(
      'abre com o primeiro serviço e profissional e busca a grade de hoje',
      () async {
        final backend = backendComBarbearias();
        final controller = _controller(await _logado(backend));

        await controller.iniciar();

        expect(controller.servico, _corte);
        expect(controller.profissional, _bruno);
        expect(controller.dia, DateTime(2026, 11, 9));
        expect(_horas(controller), hasLength(18));
        expect(
          backend.chamadas('GET /disponibilidade').single.url.queryParameters,
          {'profissional_id': _bruno.id, 'data': '2026-11-09'},
        );
      },
    );

    test('se hoje já não tem horário, abre em amanhã', () async {
      final backend = backendComBarbearias();
      final controller = _controller(
        await _logado(backend),
        agora: DateTime.parse('2026-11-09T19:00:00-03:00'),
      );

      await controller.iniciar();

      expect(controller.dia, DateTime(2026, 11, 10));
      expect(_horas(controller).first, '09:00');
      expect(
        [
          for (final r in backend.chamadas('GET /disponibilidade'))
            r.url.queryParameters['data'],
        ],
        ['2026-11-09', '2026-11-10'],
      );
    });

    test('trocar o serviço recalcula os horários sem ir ao servidor', () async {
      final backend = backendComBarbearias();
      backend.rotas['GET /disponibilidade'] = (r) =>
          gradeDoDia(r, ocupados: {'10:00'});
      final controller = _controller(await _logado(backend));
      await controller.iniciar();
      controller.escolherHorario(_as(controller, '09:30'));

      controller.escolherServico(_corteEBarba);

      expect(controller.horario, isNull);
      expect(
        _horas(controller),
        isNot(contains('09:30')),
      ); // 60 min bateria no 10:00
      expect(_horas(controller), contains('09:00'));
      expect(backend.chamadas('GET /disponibilidade'), hasLength(1));
    });

    test('trocar de profissional ou de dia busca a grade de novo', () async {
      final backend = backendComBarbearias();
      final controller = _controller(await _logado(backend));
      await controller.iniciar();

      controller.escolherProfissional(_rafael);
      controller.escolherDia(controller.dias[2]);
      await pumpEventQueue();

      final ultima = backend.chamadas('GET /disponibilidade').last;
      expect(ultima.url.queryParameters, {
        'profissional_id': _rafael.id,
        'data': '2026-11-11',
      });
      expect(controller.horarios, isA<AsyncData>());
    });

    test('reservar manda o início e o fim pela duração do serviço', () async {
      final backend = backendComBarbearias();
      final controller = _controller(await _logado(backend));
      await controller.iniciar();
      controller.escolherServico(_corteEBarba);
      controller.escolherHorario(_as(controller, '10:00'));

      final agendamento = await controller.reservar();

      expect(jsonDecode(backend.chamadas('POST /agendamentos').single.body), {
        'barbearia_id': _navalha.id,
        'profissional_id': _bruno.id,
        'servico_id': _corteEBarba.id,
        'inicio': '2026-11-09T10:00:00-03:00',
        'fim': '2026-11-09T11:00:00-03:00',
      });
      expect(agendamento!.id, 'ag-1');
      expect(controller.falha, isNull);
      expect(controller.reservando, isFalse);
    });

    test(
      'falha ao guardar no aparelho não esconde a reserva que o servidor confirmou',
      () async {
        final backend = backendComBarbearias();
        final deps = await _logado(backend);
        final registro = AgendamentosController(
          _LocalQueNaoGrava(await SharedPreferences.getInstance()),
          deps.agendamentoRepository,
          CatalogoNomes(deps.barbeariaRepository),
        );
        await registro.carregar('id-cliente1'); // a aba já aberta, ainda vazia
        final controller = ReservaController(
          barbearia: _navalha,
          profissionais: [_bruno, _rafael],
          servicos: [_corte, _corteEBarba],
          disponibilidade: deps.disponibilidadeRepository,
          agendamentos: deps.agendamentoRepository,
          registro: registro,
          agora: () => _manha,
        );
        await controller.iniciar();
        controller.escolherHorario(_as(controller, '10:00'));

        final agendamento = await controller.reservar();

        expect(agendamento?.id, 'ag-1');
        expect(controller.falha, isNull);
        expect(controller.reservando, isFalse);
        // enquanto o app está aberto, a reserva aparece na aba Agendamentos
        expect(
          registro.proximas(agendamento!.clienteId, _manha).map((r) => r.id),
          ['ag-1'],
        );
      },
    );

    test('409: avisa, tira o horário da lista e recarrega a grade', () async {
      final backend = backendComBarbearias();
      backend.rotas['POST /agendamentos'] = (_) => jsonResponse({
        'detail': 'Horário indisponível para este profissional',
      }, 409);
      final controller = _controller(await _logado(backend));
      await controller.iniciar();
      controller.escolherHorario(_as(controller, '10:00'));

      final agendamento = await controller.reservar();

      expect(agendamento, isNull);
      expect(controller.falha!.kind, ApiErrorKind.conflict);
      expect(controller.horario, isNull);
      expect(backend.chamadas('GET /disponibilidade'), hasLength(2));
      // a leitura (CQRS) ainda devolve 10:00 como livre; o app já sabe que não está
      expect(_horas(controller), isNot(contains('10:00')));
      expect(_horas(controller), containsAll(['09:30', '10:30']));
    });

    test('403 do gestor: mostra o motivo e mantém a escolha', () async {
      final backend = backendComBarbearias();
      backend.rotas['POST /agendamentos'] = (_) =>
          jsonResponse({'detail': 'Acesso negado: requer a role cliente'}, 403);
      final controller = _controller(await _logado(backend, 'gestor1'));
      await controller.iniciar();
      controller.escolherHorario(_as(controller, '10:00'));

      expect(await controller.reservar(), isNull);

      expect(controller.falha!.kind, ApiErrorKind.forbidden);
      expect(controller.horario, isNotNull);
      expect(backend.chamadas('GET /disponibilidade'), hasLength(1));
    });

    test('grade fora do ar vira erro, e tentar de novo recupera', () async {
      final backend = backendComBarbearias();
      backend.rotas['GET /disponibilidade'] = (_) =>
          jsonResponse({'detail': 'Serviço indisponível'}, 503);
      final controller = _controller(await _logado(backend));

      await controller.iniciar();
      expect(controller.horarios, isA<AsyncError>());

      backend.rotas['GET /disponibilidade'] = gradeDoDia;
      await controller.carregarHorarios();
      expect(controller.horarios, isA<AsyncData>());
    });
  });

  group('tela de reserva', () {
    Future<void> abrirReserva(WidgetTester tester, FakeBackend backend) async {
      await pumpApp(tester, backend);
      await entrarComo(tester, 'cliente1', 'cliente123');
      await tester.tap(find.text('Navalha de Ouro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reservar horário'));
      await tester.pumpAndSettle();
      // amanhã tem a grade inteira no futuro, a qualquer hora em que o teste rode
      await tester.tap(find.widgetWithText(ChoiceChip, 'Amanhã'));
      await tester.pumpAndSettle();
    }

    testWidgets('escolher horário e confirmar mostra a reserva confirmada', (
      tester,
    ) async {
      final backend = backendComBarbearias();
      await abrirReserva(tester, backend);

      final botao = find.widgetWithText(FilledButton, 'Confirmar reserva');
      expect(tester.widget<FilledButton>(botao).onPressed, isNull);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.text('Reserva confirmada'), findsOneWidget);
      expect(backend.chamadas('POST /agendamentos'), hasLength(1));

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reservar horário'),
        findsOneWidget,
      ); // de volta ao detalhe
    });

    testWidgets('409 explica a disputa e tira o horário da tela', (
      tester,
    ) async {
      final backend = backendComBarbearias();
      backend.rotas['POST /agendamentos'] = (_) => jsonResponse({
        'detail': 'Horário indisponível para este profissional',
      }, 409);
      await abrirReserva(tester, backend);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
      await tester.pumpAndSettle();

      expect(find.text('Esse horário acabou de ser reservado'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '10:00'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '10:30'), findsOneWidget);
      expect(find.text('Reserva confirmada'), findsNothing);
    });

    testWidgets('dia sem horário livre mostra o estado vazio', (tester) async {
      final backend = backendComBarbearias();
      backend.rotas['GET /disponibilidade'] = (r) => jsonResponse({
        'profissional_id': r.url.queryParameters['profissional_id'],
        'data': r.url.queryParameters['data'],
        'horarios_livres': <Object>[],
      });
      await abrirReserva(tester, backend);

      expect(find.text('Sem horários livres'), findsOneWidget);
    });

    testWidgets('gestor vê o botão de reservar desligado e o motivo', (
      tester,
    ) async {
      await pumpApp(tester, backendComBarbearias());
      await entrarComo(tester, 'gestor1', 'gestor123');
      await tester.tap(find.text('Navalha de Ouro'));
      await tester.pumpAndSettle();

      expect(
        find.text('Só contas de cliente reservam horário pelo app.'),
        findsOneWidget,
      );
      final botao = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Reservar horário'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(botao.onPressed, isNull);
    });
  });
}
