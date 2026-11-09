import '../core/formatters.dart';
import 'bff_client.dart';
import 'models/disponibilidade.dart';

/// Horários livres, vindos do lado de leitura do CQRS (disponibilidade-service).
class DisponibilidadeRepository {
  DisponibilidadeRepository(this._bff);

  final BffClient _bff;

  /// `GET /disponibilidade?profissional_id=...&data=AAAA-MM-DD`. O serviço devolve a grade
  /// do dia inteiro, inclusive horários que já passaram: quem tira é o app.
  Future<Disponibilidade> consultar(String profissionalId, DateTime dia) async {
    final json = await _bff.get(
      '/disponibilidade',
      query: {'profissional_id': profissionalId, 'data': formatDataApi(dia)},
    );
    return Disponibilidade.fromJson(json as Map<String, dynamic>);
  }
}
