import 'package:barberhub_app/state/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('começa seguindo o sistema quando não há nada salvo', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController(await SharedPreferences.getInstance());

    expect(controller.value, ThemeMode.system);
  });

  test(
    'alterna para o oposto do que está na tela e lembra ao reabrir',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      await controller.toggle(Brightness.light); // aparelho claro → escuro
      expect(controller.value, ThemeMode.dark);

      // "reabrir o app" = novo controller lendo o mesmo armazenamento
      expect(ThemeController(prefs).value, ThemeMode.dark);

      await controller.toggle(Brightness.dark);
      expect(controller.value, ThemeMode.light);
    },
  );

  test('valor salvo inválido volta para o sistema', () async {
    SharedPreferences.setMockInitialValues({
      ThemeController.storageKey: 'roxo',
    });
    final controller = ThemeController(await SharedPreferences.getInstance());

    expect(controller.value, ThemeMode.system);
  });
}
