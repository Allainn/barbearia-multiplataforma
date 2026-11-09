import 'package:flutter/foundation.dart';

import '../data/favoritos_repository.dart';
import '../data/models/barbearia.dart';

/// Barbearias favoritas. A lista, o detalhe e a aba Favoritos escutam o mesmo controller,
/// então o coração muda nos três lugares ao mesmo tempo.
class FavoritosController extends ChangeNotifier {
  FavoritosController(this._repository) : _favoritas = _repository.ler();

  final FavoritosRepository _repository;
  List<Barbearia> _favoritas;

  /// As favoritas, da mais recente para a mais antiga.
  List<Barbearia> get favoritas => List.unmodifiable(_favoritas.reversed);

  bool ehFavorita(Barbearia barbearia) => _favoritas.contains(barbearia);

  /// Marca ou desmarca. A tela muda na hora; a gravação no aparelho termina depois.
  Future<void> alternar(Barbearia barbearia) async {
    _favoritas = ehFavorita(barbearia)
        ? [
            for (final b in _favoritas)
              if (b != barbearia) b,
          ]
        : [..._favoritas, barbearia];
    notifyListeners();
    await _repository.salvar(_favoritas);
  }
}
