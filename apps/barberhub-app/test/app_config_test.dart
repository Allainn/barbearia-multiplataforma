import 'package:barberhub_app/core/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.resolve', () {
    test('no emulador Android, o padrão aponta para o host em 10.0.2.2', () {
      final config = AppConfig.resolve(
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(config.bffUrl.toString(), 'http://10.0.2.2:8010');
      expect(config.keycloakUrl.toString(), 'http://10.0.2.2:8080');
      expect(config.realm, 'barbearia');
    });

    test('na web e no iOS, o padrão é localhost', () {
      for (final (isWeb, platform) in [
        (true, TargetPlatform.android), // Chrome no Android continua web
        (false, TargetPlatform.iOS),
      ]) {
        final config = AppConfig.resolve(isWeb: isWeb, platform: platform);
        expect(config.bffUrl.toString(), 'http://localhost:8010');
      }
    });

    test('o --dart-define vence o padrão e perde a barra do final', () {
      final config = AppConfig.resolve(
        bffUrl: ' http://192.168.0.10:8010/ ',
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(config.bffUrl.toString(), 'http://192.168.0.10:8010');
    });

    test('URL sem esquema ou sem host falha logo na abertura do app', () {
      for (final invalida in ['10.0.2.2:8010', 'localhost', 'ftp://x:21']) {
        expect(
          () => AppConfig.resolve(
            bffUrl: invalida,
            isWeb: false,
            platform: TargetPlatform.android,
          ),
          throwsArgumentError,
          reason: invalida,
        );
      }
    });
  });
}
