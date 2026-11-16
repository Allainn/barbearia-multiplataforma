import 'package:shared_preferences/shared_preferences.dart';

import 'lista_local.dart';
import 'models/reserva_local.dart';

/// O cache das reservas no aparelho, em `shared_preferences`: os nomes e o preço de cada
/// agendamento, que o `GET /agendamentos` não traz, e a última lista vista, para quando a
/// rede cair (ver ADR.md).
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

  /// Reserva ilegível fica de fora, mas continua guardada (ver [ListaLocal]): os nomes
  /// dela voltam a servir numa versão do app que a entenda.
  List<ReservaLocal> ler() => _lista.ler();

  Future<void> salvar(List<ReservaLocal> reservas) => _lista.salvar(reservas);
}
