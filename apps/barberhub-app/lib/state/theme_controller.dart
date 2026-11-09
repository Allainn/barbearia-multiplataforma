import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema escolhido pelo usuário (sistema, claro ou escuro), salvo no aparelho.
///
/// `ValueNotifier` é do próprio Flutter: o esqueleto não depende do gerenciador de estado
/// que o grupo ainda vai escolher (ver ADR.md).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(this._prefs) : super(_read(_prefs));

  static const storageKey = 'tema';

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) =>
      ThemeMode.values.asNameMap()[prefs.getString(storageKey)] ??
      ThemeMode.system;

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await _prefs.setString(storageKey, mode.name);
  }
}
