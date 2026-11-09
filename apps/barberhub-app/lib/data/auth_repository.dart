import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'models/sessao.dart';

/// Login e renovação do token no Keycloak.
///
/// É a única chamada do app que não passa pelo BFF (ADR-0016): o endpoint de token recebe
/// um formulário, não JSON, e responde com `error`/`error_description` em vez de `detail`.
/// As falhas viram [ApiException], como no `BffClient`, para a tela tratar um tipo só.
class AuthRepository {
  AuthRepository({
    required this.tokenUrl,
    required this.clientId,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    DateTime Function()? agora,
  }) : _http = httpClient ?? http.Client(),
       _agora = agora ?? DateTime.now;

  final Uri tokenUrl;
  final String clientId;
  final Duration timeout;
  final http.Client _http;
  final DateTime Function() _agora;

  /// Password grant com o client público do app (atalho de demo, ver ADR.md).
  Future<Sessao> entrar(String usuario, String senha) => _token({
    'grant_type': 'password',
    'username': usuario,
    'password': senha,
  }, recusado: 'Usuário ou senha incorretos.');

  /// Troca o refresh token por um access token novo.
  Future<Sessao> renovar(String refreshToken) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
  }, recusado: 'Sua sessão expirou. Entre de novo.');

  Future<Sessao> _token(
    Map<String, String> campos, {
    required String recusado,
  }) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            tokenUrl,
            headers: {'Accept': 'application/json'},
            body: {'client_id': clientId, ...campos},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException.offline();
    } on http.ClientException {
      throw const ApiException.offline();
    }

    final status = response.statusCode;
    if (status == 200) {
      try {
        return Sessao.fromTokenResponse(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
          agora: _agora(),
        );
      } on Object {
        throw ApiException(
          ApiErrorKind.unexpected,
          'O servidor de login respondeu algo que o app não entendeu.',
          statusCode: status,
        );
      }
    }
    // 400 invalid_grant: senha errada, usuário desativado ou refresh token vencido.
    if (status == 400 || status == 401) {
      throw ApiException(
        ApiErrorKind.unauthorized,
        recusado,
        statusCode: status,
      );
    }
    if (status == 404) {
      throw ApiException(
        ApiErrorKind.notFound,
        'O Keycloak não tem o realm ou o client do app. Rode o seed do back-end.',
        statusCode: status,
      );
    }
    throw ApiException.fromResponse(status, '');
  }
}
