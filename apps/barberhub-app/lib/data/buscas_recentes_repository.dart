import 'package:shared_preferences/shared_preferences.dart';

/// As últimas buscas da aba Barbearias, guardadas no aparelho (`shared_preferences`).
///
/// Como os favoritos, são do aparelho e não da conta: o contrato não tem onde guardar
/// isso no servidor, e a busca já roda no app.
class BuscasRecentesRepository {
  BuscasRecentesRepository(this._prefs);

  static const storageKey = 'buscas_recentes';

  final SharedPreferences _prefs;

  /// Da mais recente para a mais antiga. Nada guardado vira lista vazia.
  List<String> ler() => _prefs.getStringList(storageKey) ?? [];

  Future<void> salvar(List<String> buscas) =>
      _prefs.setStringList(storageKey, buscas);
}
