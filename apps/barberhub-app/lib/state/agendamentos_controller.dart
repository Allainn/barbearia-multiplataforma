import 'package:flutter/foundation.dart';

import '../data/agendamento_repository.dart';
import '../data/api_exception.dart';
import '../data/models/reserva_local.dart';
import '../data/reservas_local_repository.dart';

/// As reservas da aba Agendamentos: lidas do aparelho, canceladas no back-end.
class AgendamentosController extends ChangeNotifier {
  AgendamentosController(this._local, this._remoto) : _reservas = _local.ler();

  final ReservasLocalRepository _local;
  final AgendamentoRepository _remoto;
  List<ReservaLocal> _reservas;
  final _cancelando = <String>{};

  /// Reservas confirmadas e ainda por vir de [clienteId], da mais próxima para a mais
  /// distante. O aparelho pode ter reservas de mais de uma conta: cada uma vê as suas.
  List<ReservaLocal> proximas(String clienteId, DateTime agora) => [
    for (final r in _reservas)
      if (r.agendamento.clienteId == clienteId && r.ativaEm(agora)) r,
  ]..sort((a, b) => a.agendamento.inicio.compareTo(b.agendamento.inicio));

  /// Reservas canceladas ou já passadas de [clienteId], da mais recente para a mais antiga.
  List<ReservaLocal> historico(String clienteId, DateTime agora) => [
    for (final r in _reservas)
      if (r.agendamento.clienteId == clienteId && !r.ativaEm(agora)) r,
  ]..sort((a, b) => b.agendamento.inicio.compareTo(a.agendamento.inicio));

  /// Cancelamento em andamento: a tela desliga o botão dessa reserva.
  bool cancelando(ReservaLocal reserva) => _cancelando.contains(reserva.id);

  /// Guarda uma reserva que o `POST /agendamentos` acabou de confirmar.
  Future<void> registrar(ReservaLocal reserva) async {
    _reservas = [
      for (final r in _reservas)
        if (r.id != reserva.id) r,
      reserva,
    ];
    notifyListeners();
    await _local.salvar(_reservas);
  }

  /// `DELETE /agendamentos/{id}` e marca como cancelada no aparelho.
  ///
  /// 404 também conta como cancelada: a reserva não existe mais no servidor (o ambiente
  /// de demo foi recriado), então não há o que manter. Outras falhas (sem rede, 503)
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
      _reservas = [
        for (final r in _reservas) r.id == reserva.id ? r.comoCancelada() : r,
      ];
      await _local.salvar(_reservas);
    } finally {
      _cancelando.remove(reserva.id);
      notifyListeners();
    }
  }
}
