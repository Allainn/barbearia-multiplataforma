import 'package:flutter/foundation.dart';

import '../data/agendamento_repository.dart';
import '../data/api_exception.dart';
import '../data/catalogo_nomes.dart';
import '../data/models/agendamento.dart';
import '../data/models/reserva_local.dart';
import '../data/reservas_local_repository.dart';
import 'async_state.dart';

/// As reservas da aba Agendamentos.
///
/// O servidor (`GET /agendamentos`) é a fonte da verdade: diz quais reservas existem e o
/// status de cada uma. O aparelho guarda só os nomes e o preço, que o contrato não traz,
/// e serve de apoio quando a rede cai (ver ADR.md).
class AgendamentosController extends ChangeNotifier {
  AgendamentosController(this._local, this._remoto, this._catalogo)
    : _cache = _local.ler();

  final ReservasLocalRepository _local;
  final AgendamentoRepository _remoto;
  final CatalogoNomes _catalogo;

  /// O que está no aparelho, de todas as contas que já entraram nele.
  List<ReservaLocal> _cache;

  AsyncState<List<ReservaLocal>> _estado = const AsyncLoading();

  /// De quem é o [_estado]: outra conta que entrar no mesmo aparelho começa do carregando,
  /// e não vê nem por um instante a lista da conta anterior.
  String? _clienteCarregado;
  var _desatualizado = false;
  var _pedido = 0;
  final _cancelando = <String>{};

  /// Carregando, erro ou as reservas de [clienteId], já com os nomes.
  AsyncState<List<ReservaLocal>> estado(String clienteId) =>
      clienteId == _clienteCarregado ? _estado : const AsyncLoading();

  /// A lista na tela é a do aparelho, porque a última leitura do servidor falhou.
  bool get desatualizado => _desatualizado;

  List<ReservaLocal> _doCliente(String clienteId) =>
      switch (estado(clienteId)) {
        AsyncData(:final value) => [
          for (final r in value)
            if (r.agendamento.clienteId == clienteId) r,
        ],
        _ => const [],
      };

  /// Reservas confirmadas e ainda por vir de [clienteId], da mais próxima para a mais
  /// distante.
  List<ReservaLocal> proximas(String clienteId, DateTime agora) => [
    for (final r in _doCliente(clienteId))
      if (r.ativaEm(agora)) r,
  ]..sort((a, b) => a.agendamento.inicio.compareTo(b.agendamento.inicio));

  /// Reservas canceladas ou já passadas de [clienteId], da mais recente para a mais antiga.
  List<ReservaLocal> historico(String clienteId, DateTime agora) => [
    for (final r in _doCliente(clienteId))
      if (!r.ativaEm(agora)) r,
  ]..sort((a, b) => b.agendamento.inicio.compareTo(a.agendamento.inicio));

  /// Cancelamento em andamento: a tela desliga o botão dessa reserva.
  bool cancelando(ReservaLocal reserva) => _cancelando.contains(reserva.id);

  /// Lê as reservas de [clienteId] do servidor e põe os nomes.
  ///
  /// Com [silencioso] (puxar para atualizar, ou depois de cancelar), a lista atual fica na
  /// tela enquanto carrega e, se a leitura falhar, continua lá marcada como
  /// [desatualizado]. Sem rede ou com o serviço fora (503), a tela mostra o que está no
  /// aparelho, também marcado, em vez de um erro sem nada: o cliente ainda vê o horário
  /// que marcou. O 401 não precisa de nada aqui: o `BffClient` já encerra a sessão.
  Future<void> carregar(String clienteId, {bool silencioso = false}) async {
    final pedido = ++_pedido;
    final atual = estado(clienteId);
    if (!silencioso || atual is! AsyncData) {
      _clienteCarregado = clienteId;
      _estado = const AsyncLoading();
      _desatualizado = false;
      notifyListeners();
    }
    try {
      final servidor = await _remoto.listar();
      final reservas = await _mesclar(clienteId, servidor);
      // Uma resposta antiga não pode passar por cima de um pedido mais novo.
      if (pedido != _pedido) return;
      _cache = [
        for (final r in _cache)
          if (r.agendamento.clienteId != clienteId) r,
        ...reservas,
      ];
      _clienteCarregado = clienteId;
      _estado = AsyncData(reservas);
      _desatualizado = false;
      notifyListeners();
    } on Object catch (erro) {
      if (pedido != _pedido) return;
      final guardadas = [
        for (final r in _cache)
          if (r.agendamento.clienteId == clienteId) r,
      ];
      final semServidor =
          erro is ApiException &&
          (erro.kind == ApiErrorKind.offline ||
              erro.kind == ApiErrorKind.unavailable);
      _clienteCarregado = clienteId;
      if (silencioso && atual is AsyncData) {
        _desatualizado = true;
      } else if (semServidor && guardadas.isNotEmpty) {
        _estado = AsyncData(guardadas);
        _desatualizado = true;
      } else {
        _estado = AsyncError(erro);
        _desatualizado = false;
      }
      notifyListeners();
      return;
    }
    // Fora do try: a lista do servidor já está na tela, e um cache que não grava não pode
    // virar tela de erro. Na próxima carga os nomes voltam do catálogo.
    try {
      await _local.salvar(_cache);
    } on Object catch (erro) {
      debugPrint('Cache das reservas não gravado: $erro');
    }
  }

  /// Uma reserva por agendamento do servidor, com o status do servidor e os nomes do
  /// cache. O que não está no cache (ou ficou sem nome numa carga anterior) vai ao
  /// catálogo; o que sumiu do servidor some daqui.
  Future<List<ReservaLocal>> _mesclar(
    String clienteId,
    List<Agendamento> servidor,
  ) async {
    final guardadas = {
      for (final r in _cache)
        if (r.agendamento.clienteId == clienteId) r.id: r,
    };
    final faltando = [
      for (final a in servidor)
        if (guardadas[a.id]?.incompleta ?? true) a,
    ];
    final resolvidas = {
      for (final r in await _catalogo.resolver(faltando)) r.id: r,
    };
    return [
      for (final a in servidor)
        switch ((guardadas[a.id], resolvidas[a.id])) {
          (final g?, final r?) => g.com(a).completadaCom(r),
          (final g?, null) => g.com(a),
          (null, final r?) => r,
          // não acontece: todo agendamento sem cache passou pelo catálogo
          (null, null) => ReservaLocal.semNomes(a),
        },
    ];
  }

  /// Guarda uma reserva que o `POST /agendamentos` acabou de confirmar, com os nomes que
  /// estavam na tela. Ela aparece na hora, sem esperar a próxima leitura do servidor.
  Future<void> registrar(ReservaLocal reserva) async {
    _cache = [
      for (final r in _cache)
        if (r.id != reserva.id) r,
      reserva,
    ];
    if (_estado case AsyncData(:final value)) {
      _estado = AsyncData([
        for (final r in value)
          if (r.id != reserva.id) r,
        reserva,
      ]);
    }
    notifyListeners();
    await _local.salvar(_cache);
  }

  /// `DELETE /agendamentos/{id}`, marca como cancelada e confere no servidor.
  ///
  /// 404 também conta como cancelada: a reserva não existe mais no servidor (o ambiente
  /// de demo foi recriado), e a releitura tira ela da lista. Outras falhas (sem rede, 503)
  /// saem como [ApiException] e a reserva continua como estava.
  Future<void> cancelar(ReservaLocal reserva) async {
    if (!_cancelando.add(reserva.id)) return;
    notifyListeners();
    try {
      try {
        await _remoto.cancelar(reserva.id);
      } on ApiException catch (erro) {
        if (erro.kind != ApiErrorKind.notFound) rethrow;
      }
      ReservaLocal marcar(ReservaLocal r) =>
          r.id == reserva.id ? r.comoCancelada() : r;
      _cache = [for (final r in _cache) marcar(r)];
      if (_estado case AsyncData(:final value)) {
        _estado = AsyncData([for (final r in value) marcar(r)]);
      }
      await _local.salvar(_cache);
    } finally {
      _cancelando.remove(reserva.id);
      notifyListeners();
    }
    // A lista passa a refletir o servidor (ex.: a do 404 acima some).
    await carregar(reserva.agendamento.clienteId, silencioso: true);
  }
}
