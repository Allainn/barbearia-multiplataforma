import 'bff_client.dart';
import 'models/agendamento.dart';

/// Reservas, no lado de escrita (agendamento-service).
class AgendamentoRepository {
  AgendamentoRepository(this._bff);

  final BffClient _bff;

  /// `POST /agendamentos`: 201 com a reserva, ou `ApiException` de conflito (409) se outro
  /// cliente reservou o mesmo horário primeiro (ADR-0007).
  Future<Agendamento> reservar(NovoAgendamento novo) async {
    final json = await _bff.post('/agendamentos', novo.toJson());
    return Agendamento.fromJson(json as Map<String, dynamic>);
  }
}
