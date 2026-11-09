import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_config.dart';
import 'data/auth_repository.dart';
import 'data/bff_client.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';

/// Raiz de composição: monta repositórios e controllers uma vez e entrega para as telas.
///
/// Sem biblioteca de estado (ADR.md), as dependências descem pelo construtor. Este objeto
/// evita que cada tela no caminho precise repassar uma lista de parâmetros.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.bffClient,
    required this.auth,
    required this.theme,
  });

  /// [httpClient] entra nos testes (um `MockClient` no lugar da rede).
  factory AppDependencies.create({
    required AppConfig config,
    required SharedPreferences prefs,
    http.Client? httpClient,
  }) {
    final auth = AuthController(
      AuthRepository(
        tokenUrl: config.tokenUrl,
        clientId: config.clientId,
        httpClient: httpClient,
      ),
    );
    final bffClient = BffClient(
      baseUrl: config.bffUrl,
      tokenProvider: auth.token,
      httpClient: httpClient,
    );
    return AppDependencies._(
      config: config,
      bffClient: bffClient,
      auth: auth,
      theme: ThemeController(prefs),
    );
  }

  final AppConfig config;
  final BffClient bffClient;
  final AuthController auth;
  final ThemeController theme;
}
