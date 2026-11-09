import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/reserva_local.dart';

/// As reservas feitas neste aparelho, guardadas em `shared_preferences` (ver ADR.md:
/// o contrato não tem `GET /agendamentos`).
class ReservasLocalRepository {
  ReservasLocalRepository(this._prefs);

  static const storageKey = 'agendamentos';

  final SharedPreferences _prefs;

  /// Dado corrompido vira lista vazia, não erro.
  List<ReservaLocal> ler() {
    final texto = _prefs.getString(storageKey);
    if (texto == null) return [];
    try {
      return [
        for (final item in jsonDecode(texto) as List)
          ReservaLocal.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> salvar(List<ReservaLocal> reservas) => _prefs.setString(
    storageKey,
    jsonEncode([for (final r in reservas) r.toJson()]),
  );
}
