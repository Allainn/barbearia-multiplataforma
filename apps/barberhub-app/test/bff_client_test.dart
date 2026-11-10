import 'dart:convert';

import 'package:barberhub_app/data/api_exception.dart';
import 'package:barberhub_app/data/bff_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Resposta como o FastAPI manda: JSON em UTF-8, sem charset no Content-Type.
http.Response _json(Object body, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

BffClient _client(MockClientHandler handler, {TokenProvider? tokenProvider}) =>
    BffClient(
      baseUrl: Uri.parse('http://10.0.2.2:8010'),
      tokenProvider: tokenProvider,
      httpClient: MockClient(handler),
    );

void main() {
  test(
    'manda o token, monta a URL com a query e decodifica os acentos',
    () async {
      late http.Request enviada;
      final client = _client((request) async {
        enviada = request;
        return _json([
          {'id': '1', 'nome': 'Barbearia São José'},
        ], 200);
      }, tokenProvider: () async => 'abc');

      final body = await client.get(
        '/disponibilidade',
        query: {'profissional_id': '22', 'data': '2026-11-09'},
      );

      expect(
        enviada.url.toString(),
        'http://10.0.2.2:8010/disponibilidade?profissional_id=22&data=2026-11-09',
      );
      expect(enviada.headers['Authorization'], 'Bearer abc');
      expect(body[0]['nome'], 'Barbearia São José');
    },
  );

  test('409 vira conflito com o "detail" do back-end', () async {
    final client = _client(
      (_) async =>
          _json({'detail': 'Horário indisponível para este profissional'}, 409),
    );

    await expectLater(
      client.post('/agendamentos', {'profissional_id': '22'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
            .having(
              (e) => e.message,
              'message',
              'Horário indisponível para este profissional',
            ),
      ),
    );
  });

  test(
    '401 sem corpo usa a mensagem padrão; 503 vira serviço fora do ar',
    () async {
      final semCorpo = _client((_) async => http.Response('', 401));
      await expectLater(
        semCorpo.get('/barbearias'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having((e) => e.message, 'message', contains('Entre de novo')),
        ),
      );

      final fora = _client(
        (_) async => _json({'detail': 'barbearia-service fora'}, 503),
      );
      await expectLater(
        fora.get('/barbearias'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unavailable,
          ),
        ),
      );
    },
  );

  test(
    '401 com token avisa quem cuida da sessão; 403 e 401 sem token, não',
    () async {
      final recusados = <String>[];
      BffClient cliente(int status, {String? token}) => BffClient(
        baseUrl: Uri.parse('http://10.0.2.2:8010'),
        tokenProvider: () async => token,
        onUnauthorized: recusados.add,
        httpClient: MockClient((_) async => http.Response('', status)),
      );

      await expectLater(
        cliente(401, token: 'abc').get('/barbearias'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        cliente(403, token: 'abc').get('/barbearias'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        cliente(401).get('/barbearias'),
        throwsA(isA<ApiException>()),
      );

      expect(recusados, ['abc']);
    },
  );

  test('falha de rede vira offline, não uma exceção do http', () async {
    final client = _client(
      (_) async => throw http.ClientException('Connection refused'),
    );

    await expectLater(
      client.get('/barbearias'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.offline),
      ),
    );
  });

  test('DELETE com 204 termina sem corpo e sem erro', () async {
    final client = _client((request) async {
      expect(request.method, 'DELETE');
      return http.Response('', 204);
    });

    await expectLater(client.delete('/agendamentos/44'), completes);
  });
}
