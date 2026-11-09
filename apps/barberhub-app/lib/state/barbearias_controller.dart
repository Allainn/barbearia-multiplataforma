import 'package:flutter/foundation.dart';

import '../data/barbearia_repository.dart';
import '../data/models/barbearia.dart';
import 'async_state.dart';
import 'filtro_barbearias.dart';

/// Estado da aba Barbearias: a lista que veio do BFF, a busca digitada e o bairro escolhido.
class BarbeariasController extends ChangeNotifier {
  BarbeariasController(this._repository);

  final BarbeariaRepository _repository;

  AsyncState<List<Barbearia>> _estado = const AsyncLoading();
  var _pedido = 0;

  AsyncState<List<Barbearia>> get estado => _estado;

  var _busca = '';

  /// O texto digitado na busca.
  String get busca => _busca;

  String? _bairro;

  /// O bairro escolhido no filtro, ou null para todos.
  String? get bairro => _bairro;

  /// As opções do filtro de bairro, tiradas das barbearias carregadas.
  List<String> get bairros => switch (_estado) {
    AsyncData(:final value) => bairrosDe(value),
    _ => const [],
  };

  /// Verdadeiro quando a lista na tela é só um pedaço do que o BFF devolveu.
  bool get filtrando => normalizar(_busca).isNotEmpty || _bairro != null;

  /// O que a tela mostra: a lista carregada, depois da busca e do filtro. Vazia fora do
  /// estado de dados.
  List<Barbearia> get visiveis => switch (_estado) {
    AsyncData(:final value) => filtrarBarbearias(
      value,
      busca: _busca,
      bairro: _bairro,
    ),
    _ => const [],
  };

  /// Escolhe um bairro; o mesmo bairro de novo, ou null, volta a mostrar todos.
  void filtrarPorBairro(String? bairro) {
    _bairro = bairro == _bairro ? null : bairro;
    notifyListeners();
  }

  void buscar(String texto) {
    if (texto == _busca) return;
    _busca = texto;
    notifyListeners();
  }

  void limparFiltros() {
    _busca = '';
    _bairro = null;
    notifyListeners();
  }

  /// Busca a lista. Com [silencioso], mantém o que está na tela enquanto carrega
  /// (puxar para atualizar); sem ele, volta para o skeleton.
  Future<void> carregar({bool silencioso = false}) async {
    final pedido = ++_pedido;
    if (!silencioso || _estado is! AsyncData) {
      _estado = const AsyncLoading();
      notifyListeners();
    }
    AsyncState<List<Barbearia>> novo;
    try {
      novo = AsyncData(await _repository.listar());
    } on Object catch (erro) {
      novo = AsyncError(erro);
    }
    // Uma resposta antiga não pode passar por cima de um pedido mais novo.
    if (pedido != _pedido) return;
    _estado = novo;
    // O bairro escolhido pode ter sumido da lista nova: sem isso a tela ficaria vazia
    // com um filtro que nem aparece mais.
    if (!bairros.contains(_bairro)) _bairro = null;
    notifyListeners();
  }
}
