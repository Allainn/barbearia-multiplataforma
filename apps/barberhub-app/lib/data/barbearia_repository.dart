import 'bff_client.dart';
import 'models/barbearia.dart';
import 'models/profissional.dart';
import 'models/servico.dart';

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

  /// `GET /barbearias/{id}/profissionais`, em ordem alfabética.
  Future<List<Profissional>> profissionais(String barbeariaId) async {
    final json =
        await _bff.get('/barbearias/$barbeariaId/profissionais') as List;
    return [
      for (final item in json)
        Profissional.fromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  /// `GET /barbearias/{id}/servicos`, do mais barato para o mais caro.
  Future<List<Servico>> servicos(String barbeariaId) async {
    final json = await _bff.get('/barbearias/$barbeariaId/servicos') as List;
    return [
      for (final item in json) Servico.fromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.preco.compareTo(b.preco));
  }
}
