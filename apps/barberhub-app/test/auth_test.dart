import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/auth_repository.dart';
import 'package:barberhub_app/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/pump_app.dart';

final _tokenUrl = Uri.parse(
  'http://10.0.2.2:8080/realms/barbearia/protocol/openid-connect/token',
);

void main() {
  group('AuthRepository', () {
    test('password grant com o client público, sem secret', () async {
      final backend = FakeBackend();
      final repository = AuthRepository(
        tokenUrl: _tokenUrl,
        clientId: 'barberhub-app',
        httpClient: backend.client,
        agora: () => DateTime.utc(2026, 11, 9, 12),
      );

      final sessao = await repository.entrar('cliente1', 'cliente123');

      final enviado = backend.requests.single;
      expect(enviado.url, _tokenUrl);
      expect(enviado.bodyFields, {
        'client_id': 'barberhub-app',
        'grant_type': 'password',
        'username': 'cliente1',
        'password': 'cliente123',
      });
      expect(sessao.usuario, 'cliente1');
      expect(sessao.nome, 'Cliente Um');
      expect(sessao.userId, 'id-cliente1');
      expect(sessao.ehCliente, isTrue);
      expect(sessao.ehGestor, isFalse);
      expect(sessao.expiraEm, DateTime.utc(2026, 11, 9, 12, 30));
    });

    test('senha errada vira erro com texto para a tela', () async {
      final repository = AuthRepository(
        tokenUrl: _tokenUrl,
        clientId: 'barberhub-app',
        httpClient: FakeBackend().client,
      );

      await expectLater(
        repository.entrar('cliente1', 'errada'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having(
                (e) => e.message,
                'message',
                'Usuário ou senha incorretos.',
              ),
        ),
      );
    });

    test('sem rede vira erro de conexão', () async {
      final backend = FakeBackend()..semRede = true;
      final repository = AuthRepository(
        tokenUrl: _tokenUrl,
        clientId: 'barberhub-app',
        httpClient: backend.client,
      );

      await expectLater(
        repository.entrar('cliente1', 'cliente123'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.offline,
          ),
        ),
      );
    });
  });

  group('AuthController', () {
    late FakeBackend backend;
    late DateTime agora;
    late AuthController auth;

    setUp(() {
      backend = FakeBackend();
      agora = DateTime.utc(2026, 11, 9, 12);
      auth = AuthController(
        AuthRepository(
          tokenUrl: _tokenUrl,
          clientId: 'barberhub-app',
          httpClient: backend.client,
          agora: () => agora,
        ),
        agora: () => agora,
      );
    });

    test('token válido é reaproveitado sem ir ao Keycloak', () async {
      await auth.entrar('cliente1', 'cliente123');

      agora = agora.add(const Duration(minutes: 20));
      final token = await auth.token();

      expect(token, auth.sessao!.accessToken);
      expect(backend.tokensEmitidos, 1);
    });

    test(
      'perto de vencer, renova uma vez só para chamadas simultâneas',
      () async {
        await auth.entrar('cliente1', 'cliente123');

        agora = agora.add(const Duration(minutes: 29, seconds: 45));
        final tokens = await Future.wait([
          auth.token(),
          auth.token(),
          auth.token(),
        ]);

        expect(tokens.toSet(), hasLength(1));
        expect(backend.tokensEmitidos, 2);
        expect(backend.requests.last.bodyFields['grant_type'], 'refresh_token');
        expect(auth.logado, isTrue);
      },
    );

    test('renovação recusada derruba a sessão e avisa o motivo', () async {
      await auth.entrar('cliente1', 'cliente123');
      var avisos = 0;
      auth.addListener(() => avisos++);

      backend.recusarRenovacao = true;
      agora = agora.add(const Duration(minutes: 31));

      expect(await auth.token(), isNull);
      expect(auth.logado, isFalse);
      expect(auth.erro?.message, 'Sua sessão expirou. Entre de novo.');
      expect(avisos, 1);
    });

    test('sem rede na renovação, a sessão continua', () async {
      await auth.entrar('cliente1', 'cliente123');

      backend.semRede = true;
      agora = agora.add(const Duration(minutes: 31));

      expect(await auth.token(), isNotNull);
      expect(auth.logado, isTrue);
    });
  });

  group('tela de login', () {
    testWidgets('o app abre no login e entra com usuário e senha', (
      tester,
    ) async {
      await pumpApp(tester, FakeBackend());

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('BarberHub'), findsOneWidget);

      await entrarComo(tester, 'cliente1', 'cliente123');

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('senha errada mostra o erro e continua no login', (
      tester,
    ) async {
      await pumpApp(tester, FakeBackend());

      await entrarComo(tester, 'cliente1', 'errada');

      expect(find.text('Usuário ou senha incorretos.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('campos vazios não chamam o Keycloak', (tester) async {
      final backend = FakeBackend();
      await pumpApp(tester, backend);

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o usuário'), findsOneWidget);
      expect(find.text('Informe a senha'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('a aba Conta mostra quem entrou e o Sair volta para o login', (
      tester,
    ) async {
      await pumpApp(tester, FakeBackend());
      await entrarComo(tester, 'gestor1', 'gestor123');

      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();
      expect(find.text('Gestor Um'), findsOneWidget);
      expect(find.text('gestor1'), findsOneWidget);
      expect(
        find.text('Só contas de cliente reservam horário pelo app.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });
  });
}
