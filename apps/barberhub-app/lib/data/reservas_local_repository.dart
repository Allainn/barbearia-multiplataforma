import 'package:shared_preferences/shared_preferences.dart';

import 'lista_local.dart';
import 'models/reserva_local.dart';

/// As reservas feitas neste aparelho, guardadas em `shared_preferences` (ver ADR.md:
/// o contrato não tem `GET /agendamentos`).
class ReservasLocalRepository {
  ReservasLocalRepository(SharedPreferences prefs)
    : _lista = ListaLocal(
        prefs,
        storageKey,
        fromJson: ReservaLocal.fromJson,
        toJson: (reserva) => reserva.toJson(),
      );

  static const storageKey = 'agendamentos';

  final ListaLocal<ReservaLocal> _lista;

  /// Reserva ilegível fica de fora, mas continua guardada (ver [ListaLocal]): é a única
  /// cópia que o cliente tem dela.
  List<ReservaLocal> ler() => _lista.ler();

  Future<void> salvar(List<ReservaLocal> reservas) => _lista.salvar(reservas);
}
