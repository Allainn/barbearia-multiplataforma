import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Resposta como o FastAPI manda: JSON em UTF-8, sem charset no Content-Type.
http.Response jsonResponse(Object? body, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Access token com o formato do Keycloak (a assinatura é falsa: o app não a confere).
String fakeJwt({
  String sub = 'id-cliente1',
  String usuario = 'cliente1',
  String nome = 'Cliente Um',
  List<String> roles = const ['cliente'],
}) {
  String parte(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return [
    parte({'alg': 'RS256', 'typ': 'JWT'}),
    parte({
      'sub': sub,
      'preferred_username': usuario,
      'name': nome,
      'realm_access': {'roles': roles},
      'aud': ['bff-gateway', 'account'],
    }),
    'assinatura',
  ].join('.');
}

typedef Rota = FutureOr<http.Response> Function(http.Request request);

/// Keycloak e BFF de mentira, para os testes rodarem sem rede.
///
/// O endpoint de token aceita os usuários do seed; as rotas do BFF entram em [rotas],
/// com a chave `'GET /barbearias'`. Rota não cadastrada responde 404 com `detail`.
class FakeBackend {
  FakeBackend({Map<String, Rota>? rotas}) : rotas = {...?rotas};

  static const _senhas = {
    'cliente1': 'cliente123',
    'cliente2': 'cliente123',
    'gestor1': 'gestor123',
  };

  final Map<String, Rota> rotas;

  /// Tudo o que o app mandou, na ordem.
  final requests = <http.Request>[];

  /// Quantas vezes o app pediu token (login + renovações).
  var tokensEmitidos = 0;

  /// Validade do access token devolvido, em segundos.
  var expiresIn = 1800;

  /// Quando verdadeiro, o Keycloak recusa o refresh token (sessão encerrada no servidor).
  var recusarRenovacao = false;

  /// Quando verdadeiro, nenhuma chamada chega: simula o aparelho sem rede.
  var semRede = false;

  http.Client get client => MockClient(_responder);

  /// Chamadas feitas a uma rota do BFF, ex.: `chamadas('GET /barbearias')`.
  List<http.Request> chamadas(String rota) => [
    for (final r in requests)
      if ('${r.method} ${r.url.path}' == rota) r,
  ];

  Future<http.Response> _responder(http.Request request) async {
    if (semRede) throw http.ClientException('sem rede', request.url);
    requests.add(request);
    if (request.url.path.endsWith('/protocol/openid-connect/token')) {
      return _token(request);
    }
    final rota = rotas['${request.method} ${request.url.path}'];
    if (rota == null) return jsonResponse({'detail': 'Não encontrado'}, 404);
    return rota(request);
  }

  http.Response _token(http.Request request) {
    final campos = request.bodyFields;
    final String usuario;
    if (campos['grant_type'] == 'refresh_token') {
      final refresh = campos['refresh_token'] ?? '';
      if (recusarRenovacao || !refresh.startsWith('refresh-')) {
        return jsonResponse({'error': 'invalid_grant'}, 400);
      }
      usuario = refresh.split('-')[1];
    } else {
      usuario = campos['username'] ?? '';
      if (_senhas[usuario] != campos['password']) {
        return jsonResponse({
          'error': 'invalid_grant',
          'error_description': 'Invalid user credentials',
        }, 400);
      }
    }
    tokensEmitidos++;
    final gestor = usuario.startsWith('gestor');
    return jsonResponse({
      'access_token': fakeJwt(
        sub: 'id-$usuario',
        usuario: usuario,
        nome: gestor
            ? 'Gestor Um'
            : 'Cliente ${usuario.endsWith('2') ? 'Dois' : 'Um'}',
        roles: [gestor ? 'gestor' : 'cliente'],
      ),
      'refresh_token': 'refresh-$usuario-$tokensEmitidos',
      'expires_in': expiresIn,
      'token_type': 'Bearer',
    });
  }
}
