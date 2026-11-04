import 'package:barberhub_app/app.dart';
import 'package:barberhub_app/core/app_config.dart';
import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/bff_client.dart';
import 'package:barberhub_app/state/theme_controller.dart';
import 'package:barberhub_app/ui/theme/app_theme.dart';
import 'package:barberhub_app/ui/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('abre com a URL do BFF e troca de tema pelo botão', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final config = AppConfig.resolve(
      isWeb: false,
      platform: TargetPlatform.android,
    );
    final themeController = ThemeController(
      await SharedPreferences.getInstance(),
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      BarberHubApp(
        config: config,
        bffClient: BffClient(baseUrl: config.bffUrl),
        themeController: themeController,
      ),
    );

    expect(find.text('http://10.0.2.2:8010'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.byTooltip('Usar tema claro'), findsOneWidget);
  });

  testWidgets(
    'ErrorView mostra o texto do back-end e o botão de tentar de novo',
    (tester) async {
      var tentativas = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ErrorView(
              error: const ApiException(
                ApiErrorKind.conflict,
                'Horário indisponível para este profissional',
                statusCode: 409,
              ),
              onRetry: () => tentativas++,
            ),
          ),
        ),
      );

      expect(find.text('Horário indisponível'), findsOneWidget);
      expect(
        find.text('Horário indisponível para este profissional'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar de novo'));
      expect(tentativas, 1);
    },
  );
}
