import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Uma lista de objetos guardada como JSON numa chave do `shared_preferences`.
///
/// Um item que o app não consegue ler (formato antigo, status que o app não conhece) fica
/// fora da lista que a tela vê, mas não é apagado: volta para o aparelho a cada [salvar].
/// Sem isso, um item ruim fazia a lista inteira parecer vazia, e a gravação seguinte
/// apagava as outras de verdade.
class ListaLocal<T> {
  ListaLocal(
    this._prefs,
    this.storageKey, {
    required this.fromJson,
    required this.toJson,
  });

  final SharedPreferences _prefs;
  final String storageKey;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;

  /// Os itens que a última [ler] não entendeu, guardados como vieram.
  var _ilegiveis = const <Object?>[];

  /// Na ordem em que foram guardados. Texto que nem é uma lista JSON vira lista vazia.
  List<T> ler() {
    _ilegiveis = const [];
    final texto = _prefs.getString(storageKey);
    if (texto == null) return [];
    final Object? lista;
    try {
      lista = jsonDecode(texto);
    } on FormatException {
      return [];
    }
    if (lista is! List) return [];
    final itens = <T>[];
    final ilegiveis = <Object?>[];
    for (final item in lista) {
      try {
        itens.add(fromJson(item as Map<String, dynamic>));
      } on Object {
        ilegiveis.add(item);
      }
    }
    _ilegiveis = ilegiveis;
    return itens;
  }

  Future<void> salvar(List<T> itens) => _prefs.setString(
    storageKey,
    jsonEncode([for (final item in itens) toJson(item), ..._ilegiveis]),
  );
}
