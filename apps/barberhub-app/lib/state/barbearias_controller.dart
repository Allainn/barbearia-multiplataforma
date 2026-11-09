import 'package:flutter/foundation.dart';

import '../data/barbearia_repository.dart';
import '../data/models/barbearia.dart';
import 'async_state.dart';

/// Estado da aba Barbearias: a lista que veio do BFF.
class BarbeariasController extends ChangeNotifier {
  BarbeariasController(this._repository);

  final BarbeariaRepository _repository;

  AsyncState<List<Barbearia>> _estado = const AsyncLoading();
  var _pedido = 0;

  AsyncState<List<Barbearia>> get estado => _estado;

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
    notifyListeners();
  }
}
