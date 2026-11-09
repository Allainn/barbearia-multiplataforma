import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/ui/screens/guia_visual_screen.dart';
import 'package:barberhub_app/ui/theme/app_theme.dart';
import 'package:barberhub_app/ui/widgets/monogram.dart';
import 'package:barberhub_app/ui/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/pump_app.dart';

/// Abre o app já logado como cliente1, com o back-end falso.
Future<void> _abrirApp(WidgetTester tester) async {
  await pumpApp(tester, FakeBackend());
  await entrarComo(tester, 'cliente1', 'cliente123');
}

Brightness _brilho(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NavigationBar))).brightness;

void main() {
  testWidgets('abre na aba Barbearias e troca de aba pela barra de baixo', (
    tester,
  ) async {
    await _abrirApp(tester);

    expect(find.widgetWithText(AppBar, 'Barbearias'), findsOneWidget);

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Favoritos'), findsOneWidget);
  });

  testWidgets('a aba Conta mostra o BFF em uso e troca o tema', (tester) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Conta'));
    await tester.pumpAndSettle();

    expect(find.text('http://10.0.2.2:8010'), findsOneWidget);
    expect(_brilho(tester), Brightness.light);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(_brilho(tester), Brightness.dark);
  });

  testWidgets('o guia visual monta sem erro nos dois temas', (tester) async {
    for (final tema in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(theme: tema, home: const GuiaVisualScreen()),
      );
      // o shimmer anima para sempre: avança um pouco em vez de pumpAndSettle
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Guia visual'), findsOneWidget);
    }
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

  test('iniciais do monograma ignoram preposições', () {
    expect(Monogram.iniciais('Barbearia Centro'), 'BC');
    expect(Monogram.iniciais('Barbearia do Zé'), 'BZ');
    expect(Monogram.iniciais('Carlos'), 'C');
    expect(Monogram.iniciais('  '), '?');
  });
}
