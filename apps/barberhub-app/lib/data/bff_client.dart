import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Devolve o access token do usuário logado, ou null se ninguém entrou ainda.
typedef TokenProvider = Future<String?> Function();

/// Avisado quando o BFF responde 401 a uma chamada feita com [token].
typedef UnauthorizedHandler = void Function(String token);

/// Único ponto do app que fala HTTP com o BFF.
///
/// A tela não chama este cliente: cada feature cria o seu repositório em `lib/data/`,
/// que chama [get]/[post]/[delete] e converte o JSON em modelo. Toda falha vira
/// [ApiException], então a tela trata um tipo de erro só.
class BffClient {
  BffClient({
    required this.baseUrl,
    TokenProvider? tokenProvider,
    UnauthorizedHandler? onUnauthorized,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _tokenProvider = tokenProvider,
       _onUnauthorized = onUnauthorized,
       _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final TokenProvider? _tokenProvider;

  /// Quem cuida da sessão: um 401 com token quer dizer que o token deixou de valer.
  final UnauthorizedHandler? _onUnauthorized;
  final http.Client _http;

  /// JSON decodificado (`List` ou `Map`). [path] começa com "/", ex.: `/barbearias`.
  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body: body);

  Future<void> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    assert(path.startsWith('/'), 'o caminho começa com "/": $path');
    final request = http.Request(method, _uri(path, query))
      ..headers['Accept'] = 'application/json';
    final token = await _tokenProvider?.call();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException.offline();
    } on http.ClientException {
      // Sem rede, porta fechada ou, na web, bloqueio de CORS.
      throw const ApiException.offline();
    }

    // O FastAPI não manda charset no Content-Type; decodificar como UTF-8 preserva os acentos.
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    if (response.statusCode == 401 && token != null) {
      _onUnauthorized?.call(token);
    }
    throw ApiException.fromResponse(response.statusCode, text);
  }

  Uri _uri(String path, Map<String, String>? query) => baseUrl.replace(
    path: '${baseUrl.path}$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );
}
