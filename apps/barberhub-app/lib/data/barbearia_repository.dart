import 'bff_client.dart';
import 'models/barbearia.dart';

/// Barbearias, vindas do BFF. Converte o JSON do contrato em modelo.
class BarbeariaRepository {
  BarbeariaRepository(this._bff);

  final BffClient _bff;

  /// `GET /barbearias`, em ordem alfabética (o serviço não garante ordem).
  Future<List<Barbearia>> listar() async {
    final json = await _bff.get('/barbearias') as List;
    return [
      for (final item in json) Barbearia.fromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }
}
