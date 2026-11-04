import 'package:flutter/foundation.dart';

/// Endereços do back-end, escolhidos na hora de rodar o app, nunca fixos no código:
///
///   flutter run --dart-define=BFF_URL=http://192.168.0.10:8010
///
/// Sem `--dart-define`, vale o padrão de cada plataforma: o emulador Android enxerga o
/// computador em 10.0.2.2; web e simulador iOS, em localhost.
class AppConfig {
  const AppConfig({
    required this.bffUrl,
    required this.keycloakUrl,
    required this.realm,
  });

  /// Entrada da API (bff-gateway, porta 8010). Sem barra no final.
  final Uri bffUrl;

  /// Keycloak (porta 8080), para o login. Sem barra no final.
  final Uri keycloakUrl;

  final String realm;

  factory AppConfig.fromEnvironment() => AppConfig.resolve(
    bffUrl: const String.fromEnvironment('BFF_URL'),
    keycloakUrl: const String.fromEnvironment('KEYCLOAK_URL'),
    realm: const String.fromEnvironment(
      'KEYCLOAK_REALM',
      defaultValue: 'barbearia',
    ),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  /// Separado de [AppConfig.fromEnvironment] para os testes simularem plataforma e valores.
  static AppConfig resolve({
    String bffUrl = '',
    String keycloakUrl = '',
    String realm = 'barbearia',
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    final host = !isWeb && platform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return AppConfig(
      bffUrl: _parse('BFF_URL', bffUrl.isEmpty ? 'http://$host:8010' : bffUrl),
      keycloakUrl: _parse(
        'KEYCLOAK_URL',
        keycloakUrl.isEmpty ? 'http://$host:8080' : keycloakUrl,
      ),
      realm: realm,
    );
  }

  static Uri _parse(String name, String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        name,
        'use uma URL http(s) completa, ex.: http://10.0.2.2:8010',
      );
    }
    // As rotas do BFF começam com "/" (ex.: /barbearias): a base fica sem barra no final.
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }
}
