import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/barbearia.dart';

/// Barbearias favoritas, guardadas no aparelho (`shared_preferences`).
///
/// Guarda a barbearia inteira, não só o id: a aba Favoritos abre sem rede e sem esperar
/// o BFF. O contrato não tem favoritos no servidor, então eles são do aparelho, não da conta.
class FavoritosRepository {
  FavoritosRepository(this._prefs);

  static const storageKey = 'favoritos';

  final SharedPreferences _prefs;

  /// Na ordem em que foram favoritadas. Dado corrompido vira lista vazia, não erro.
  List<Barbearia> ler() {
    final texto = _prefs.getString(storageKey);
    if (texto == null) return [];
    try {
      return [
        for (final item in jsonDecode(texto) as List)
          Barbearia.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> salvar(List<Barbearia> favoritas) => _prefs.setString(
    storageKey,
    jsonEncode([for (final b in favoritas) b.toJson()]),
  );
}
