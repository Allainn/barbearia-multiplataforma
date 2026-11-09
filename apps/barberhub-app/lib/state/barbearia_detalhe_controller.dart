import 'package:flutter/foundation.dart';

import '../data/barbearia_repository.dart';
import '../data/models/barbearia.dart';
import '../data/models/profissional.dart';
import '../data/models/servico.dart';
import 'async_state.dart';

/// O que a tela de detalhe mostra além da própria barbearia.
class DetalheBarbearia {
  const DetalheBarbearia({required this.profissionais, required this.servicos});

  final List<Profissional> profissionais;
  final List<Servico> servicos;

  /// Sem profissional ou sem serviço não há o que reservar.
  bool get podeReservar => profissionais.isNotEmpty && servicos.isNotEmpty;
}

/// Estado da tela de detalhe. Vive enquanto a tela está aberta.
class BarbeariaDetalheController extends ChangeNotifier {
  BarbeariaDetalheController(this._repository, this.barbearia);

  final BarbeariaRepository _repository;
  final Barbearia barbearia;

  AsyncState<DetalheBarbearia> _estado = const AsyncLoading();
  var _descartado = false;

  AsyncState<DetalheBarbearia> get estado => _estado;

  /// Profissionais e serviços em paralelo; se um dos dois falhar, a tela mostra o erro
  /// (meia tela preenchida esconderia o problema).
  Future<void> carregar() async {
    _mudar(const AsyncLoading());
    try {
      final profissionais = _repository.profissionais(barbearia.id);
      final servicos = _repository.servicos(barbearia.id);
      // Espera as duas; se uma falhar, o erro sai daqui e a outra não fica solta.
      await Future.wait([profissionais, servicos]);
      _mudar(
        AsyncData(
          DetalheBarbearia(
            profissionais: await profissionais,
            servicos: await servicos,
          ),
        ),
      );
    } on Object catch (erro) {
      _mudar(AsyncError(erro));
    }
  }

  void _mudar(AsyncState<DetalheBarbearia> novo) {
    if (_descartado) return; // a tela fechou antes de a resposta chegar
    _estado = novo;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
