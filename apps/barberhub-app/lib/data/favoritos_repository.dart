import 'package:shared_preferences/shared_preferences.dart';

import 'lista_local.dart';
import 'models/barbearia.dart';

/// Barbearias favoritas, guardadas no aparelho (`shared_preferences`).
///
/// Guarda a barbearia inteira, não só o id: a aba Favoritos abre sem rede e sem esperar
/// o BFF. O contrato não tem favoritos no servidor, então eles são do aparelho, não da conta.
class FavoritosRepository {
  FavoritosRepository(SharedPreferences prefs)
    : _lista = ListaLocal(
        prefs,
        storageKey,
        fromJson: Barbearia.fromJson,
        toJson: (barbearia) => barbearia.toJson(),
      );

  static const storageKey = 'favoritos';

  final ListaLocal<Barbearia> _lista;

  /// Na ordem em que foram favoritadas. Item ilegível fica de fora, mas continua
  /// guardado (ver [ListaLocal]).
  List<Barbearia> ler() => _lista.ler();

  Future<void> salvar(List<Barbearia> favoritas) => _lista.salvar(favoritas);
}
