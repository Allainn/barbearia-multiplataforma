import 'package:flutter/foundation.dart';

import '../data/agendamento_repository.dart';
import '../data/api_exception.dart';
import '../data/disponibilidade_repository.dart';
import '../data/models/agendamento.dart';
import '../data/models/barbearia.dart';
import '../data/models/disponibilidade.dart';
import '../data/models/profissional.dart';
import '../data/models/servico.dart';
import 'async_state.dart';
import 'horarios.dart';

/// Estado da tela de reserva: o que foi escolhido, os horários livres e o envio.
class ReservaController extends ChangeNotifier {
  ReservaController({
    required this.barbearia,
    required this.profissionais,
    required this.servicos,
    required DisponibilidadeRepository disponibilidade,
    required AgendamentoRepository agendamentos,
    Servico? servicoInicial,
    DateTime Function()? agora,
  }) : assert(profissionais.isNotEmpty && servicos.isNotEmpty),
       _disponibilidade = disponibilidade,
       _agendamentos = agendamentos,
       _agora = agora ?? DateTime.now,
       _servico = servicoInicial ?? servicos.first,
       _profissional = profissionais.first {
    dias = proximosDias(_agora());
    _dia = dias.first;
  }

  final Barbearia barbearia;
  final List<Profissional> profissionais;
  final List<Servico> servicos;
  final DisponibilidadeRepository _disponibilidade;
  final AgendamentoRepository _agendamentos;
  final DateTime Function() _agora;

  /// Hoje e os próximos dias, no calendário da barbearia.
  late final List<DateTime> dias;

  Servico _servico;
  Profissional _profissional;
  late DateTime _dia;
  HorarioLivre? _horario;

  AsyncState<List<HorarioLivre>> _blocos = const AsyncLoading();
  final _recusados = <String, List<HorarioLivre>>{};
  var _pedido = 0;
  var _reservando = false;
  ApiException? _falha;
  var _descartado = false;

  Servico get servico => _servico;

  Profissional get profissional => _profissional;

  DateTime get dia => _dia;

  /// O horário escolhido, já com o fim calculado pela duração do serviço.
  HorarioLivre? get horario => _horario;

  DateTime get agora => _agora();

  /// Os horários em que o serviço escolhido cabe, no dia e com o profissional escolhidos.
  AsyncState<List<HorarioLivre>> get horarios => switch (_blocos) {
    AsyncData(:final value) => AsyncData(
      horariosParaServico(
        value,
        duracaoMin: _servico.duracaoMin,
        agora: _agora(),
        recusados: _recusados[_profissional.id] ?? const [],
      ),
    ),
    AsyncLoading() => const AsyncLoading(),
    AsyncError(:final error) => AsyncError(error),
  };

  /// Envio da reserva em andamento.
  bool get reservando => _reservando;

  /// Por que a última tentativa de reservar falhou (409, 403, sem rede...).
  ApiException? get falha => _falha;

  /// Primeira carga. Se hoje não tem mais horário (a barbearia já fechou), abre em amanhã.
  Future<void> iniciar() async {
    await carregarHorarios();
    if (_descartado) return;
    if (horarios case AsyncData(
      :final value,
    ) when value.isEmpty && _dia == dias.first && dias.length > 1) {
      _dia = dias[1];
      await carregarHorarios();
    }
  }

  void escolherServico(Servico servico) {
    if (servico == _servico) return;
    _servico = servico;
    _horario =
        null; // a duração mudou: o fim do horário escolhido não vale mais
    _falha = null;
    _avisar();
  }

  void escolherProfissional(Profissional profissional) {
    if (profissional == _profissional) return;
    _profissional = profissional;
    carregarHorarios();
  }

  void escolherDia(DateTime dia) {
    if (dia == _dia) return;
    _dia = dia;
    carregarHorarios();
  }

  void escolherHorario(HorarioLivre horario) {
    _horario = horario == _horario ? null : horario;
    _falha = null;
    _avisar();
  }

  /// Busca a grade do profissional no dia. [manterAviso] preserva a mensagem do 409
  /// enquanto a lista recarrega.
  Future<void> carregarHorarios({bool manterAviso = false}) async {
    final pedido = ++_pedido;
    _horario = null;
    if (!manterAviso) _falha = null;
    _blocos = const AsyncLoading();
    _avisar();
    AsyncState<List<HorarioLivre>> novo;
    try {
      final resposta = await _disponibilidade.consultar(_profissional.id, _dia);
      novo = AsyncData(resposta.horariosLivres);
    } on Object catch (erro) {
      novo = AsyncError(erro);
    }
    // o usuário já trocou de dia ou de profissional
    if (pedido != _pedido) return;
    _blocos = novo;
    _avisar();
  }

  /// Envia a reserva. Devolve o agendamento criado, ou null se falhou (o motivo fica em
  /// [falha]).
  ///
  /// No 409, outro cliente ficou com o horário: ele sai da lista na hora, sem esperar a
  /// leitura (que é atualizada por evento e pode demorar um instante), e a grade recarrega.
  Future<Agendamento?> reservar() async {
    final horario = _horario;
    if (horario == null || _reservando) return null;
    _reservando = true;
    _falha = null;
    _avisar();
    try {
      return await _agendamentos.reservar(
        NovoAgendamento(
          barbeariaId: barbearia.id,
          profissionalId: _profissional.id,
          servicoId: _servico.id,
          horario: horario,
        ),
      );
    } on ApiException catch (erro) {
      _falha = erro;
      if (erro.kind == ApiErrorKind.conflict) {
        (_recusados[_profissional.id] ??= []).add(horario);
        _reservando = false;
        await carregarHorarios(manterAviso: true);
      }
      return null;
    } finally {
      _reservando = false;
      _avisar();
    }
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
