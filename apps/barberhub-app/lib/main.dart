import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_dependencies.dart';
import 'core/app_config.dart';

// Camadas (README.md): core = configuração · data = BFF, Keycloak e armazenamento local ·
// state = estado da tela · ui = widgets. A UI nunca faz HTTP direto.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // necessário antes do SharedPreferences
  final dependencies = AppDependencies.create(
    config: AppConfig.fromEnvironment(),
    prefs: await SharedPreferences.getInstance(),
  );
  runApp(BarberHubApp(dependencies: dependencies));
}
