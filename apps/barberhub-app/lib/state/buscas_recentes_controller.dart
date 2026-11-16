import 'package:flutter/foundation.dart';

import '../data/buscas_recentes_repository.dart';
import 'filtro_barbearias.dart';

/// Quantas buscas o app lembra.
const maxBuscasRecentes = 5;

/// Põe [termo] no topo de [recentes], sem repetir e com no máximo [max] itens.
///
/// "Navalha", "navalha " e "NAVALHA" são a mesma busca (comparadas por [normalizar]):
/// fica uma só, escrita como na última vez. Termo vazio não muda nada.
List<String> registrarBusca(
  List<String> recentes,
  String termo, {
  int max = maxBuscasRecentes,
}) {
  final limpo = termo.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpo.isEmpty) return recentes;
  final chave = normalizar(limpo);
  return [
    limpo,
    for (final b in recentes)
      if (normalizar(b) != chave) b,
  ].take(max).toList();
}

/// As buscas recentes da aba Barbearias. A tela registra uma busca quando a pessoa
/// confirma no teclado ou abre uma barbearia a partir do resultado.
class BuscasRecentesController extends ChangeNotifier {
  BuscasRecentesController(this._repository) : _recentes = _repository.ler();

  final BuscasRecentesRepository _repository;
  List<String> _recentes;

  /// Da mais recente para a mais antiga.
  List<String> get recentes => List.unmodifiable(_recentes);

  /// A tela muda na hora; a gravação no aparelho termina depois.
  Future<void> registrar(String termo) async {
    final novas = registrarBusca(_recentes, termo);
    if (listEquals(novas, _recentes)) return;
    _recentes = novas;
    notifyListeners();
    await _repository.salvar(_recentes);
  }

  Future<void> remover(String termo) async {
    _recentes = [
      for (final b in _recentes)
        if (b != termo) b,
    ];
    notifyListeners();
    await _repository.salvar(_recentes);
  }

  Future<void> limpar() async {
    _recentes = [];
    notifyListeners();
    await _repository.salvar(_recentes);
  }
}
