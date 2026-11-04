import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_config.dart';
import 'data/bff_client.dart';
import 'state/theme_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

/// Raiz do app: tema claro/escuro, português do Brasil e a primeira tela.
///
/// Até o grupo escolher o gerenciador de estado (ADR.md), as dependências descem
/// pelo construtor: quem precisar do BFF recebe [bffClient] daqui.
class BarberHubApp extends StatelessWidget {
  const BarberHubApp({
    super.key,
    required this.config,
    required this.bffClient,
    required this.themeController,
  });

  final AppConfig config;
  final BffClient bffClient;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'BarberHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        // Textos prontos do Material (calendário, "Voltar", "Colar") em português.
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeScreen(config: config, themeController: themeController),
      ),
    );
  }
}
