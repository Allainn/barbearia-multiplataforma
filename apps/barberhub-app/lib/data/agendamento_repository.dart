import 'bff_client.dart';
import 'models/agendamento.dart';

/// Reservas do cliente no agendamento-service, pelo BFF.
class AgendamentoRepository {
  AgendamentoRepository(this._bff);

  final BffClient _bff;

  /// `GET /agendamentos`: as reservas do cliente do token, confirmadas e canceladas, no
  /// formato do 201. `[]` para quem ainda não reservou (ADR-0016).
  Future<List<Agendamento>> listar() async {
    final json = await _bff.get('/agendamentos') as List;
    return [
      for (final item in json)
        Agendamento.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// `POST /agendamentos`: 201 com a reserva, ou `ApiException` de conflito (409) se outro
  /// cliente reservou o mesmo horário primeiro (ADR-0007).
  Future<Agendamento> reservar(NovoAgendamento novo) async {
    final json = await _bff.post('/agendamentos', novo.toJson());
    return Agendamento.fromJson(json as Map<String, dynamic>);
  }

  /// `DELETE /agendamentos/{id}`: 204, ou 404 se a reserva não existe ou é de outro
  /// cliente. Repetir o cancelamento não dá erro.
  Future<void> cancelar(String agendamentoId) =>
      _bff.delete('/agendamentos/$agendamentoId');
}
