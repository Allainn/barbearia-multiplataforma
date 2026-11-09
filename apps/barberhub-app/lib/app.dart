import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_dependencies.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/shell_screen.dart';
import 'ui/theme/app_theme.dart';

/// Raiz do app: tema claro/escuro, português do Brasil e a troca entre login e abas.
class BarberHubApp extends StatefulWidget {
  const BarberHubApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<BarberHubApp> createState() => _BarberHubAppState();
}

class _BarberHubAppState extends State<BarberHubApp> {
  final _navigator = GlobalKey<NavigatorState>();

  AppDependencies get _deps => widget.dependencies;

  @override
  void initState() {
    super.initState();
    _deps.auth.addListener(_aoMudarSessao);
  }

  @override
  void dispose() {
    _deps.auth.removeListener(_aoMudarSessao);
    super.dispose();
  }

  /// Saiu (ou a sessão caiu) com uma tela aberta por cima das abas: fecha tudo, para o
  /// login não ficar escondido atrás do detalhe ou da reserva.
  void _aoMudarSessao() {
    if (!_deps.auth.logado) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _deps.theme,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'BarberHub',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        // Textos prontos do Material (calendário, "Voltar", "Colar") em português.
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ListenableBuilder(
          listenable: _deps.auth,
          builder: (context, _) => _deps.auth.logado
              ? ShellScreen(dependencies: _deps)
              : LoginScreen(auth: _deps.auth),
        ),
      ),
    );
  }
}
