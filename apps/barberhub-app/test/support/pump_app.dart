import 'package:barberhub_app/app.dart';
import 'package:barberhub_app/app_dependencies.dart';
import 'package:barberhub_app/core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

/// Dependências reais do app, com o [backend] falso no lugar da rede.
Future<AppDependencies> criarDependencias(
  FakeBackend backend, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppDependencies.create(
    config: AppConfig.resolve(isWeb: false, platform: TargetPlatform.android),
    prefs: await SharedPreferences.getInstance(),
    httpClient: backend.client,
  );
}

/// Abre o app inteiro (começa na tela de login), no tema claro.
Future<AppDependencies> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  Map<String, Object> prefs = const {},
}) async {
  final dependencies = await criarDependencias(backend, prefs: prefs);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(BarberHubApp(dependencies: dependencies));
  return dependencies;
}

/// Preenche a tela de login e espera as abas aparecerem (ou o erro).
Future<void> entrarComo(
  WidgetTester tester,
  String usuario,
  String senha,
) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Usuário'),
    usuario,
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), senha);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}
