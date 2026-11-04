import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/bff_client.dart';
import 'state/theme_controller.dart';

// Camadas (README.md): core = configuração · data = BFF e armazenamento local ·
// state = estado da tela · ui = widgets. A UI nunca faz HTTP direto.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // necessário antes do SharedPreferences
  final config = AppConfig.fromEnvironment();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    BarberHubApp(
      config: config,
      // tokenProvider entra com a feature de login (ADR.md, questões em aberto)
      bffClient: BffClient(baseUrl: config.bffUrl),
      themeController: ThemeController(prefs),
    ),
  );
}
