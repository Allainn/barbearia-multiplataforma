import 'dart:convert';

/// Tipos de falha que a tela precisa distinguir (ícone, texto e se dá para tentar de novo).
enum ApiErrorKind {
  /// Sem rede, back-end fora do ar ou demorou demais para responder.
  offline,

  /// 401: sem token, ou token vencido.
  unauthorized,

  /// 403: a role do usuário não pode usar a rota (ex.: gestor tentando reservar).
  forbidden,

  /// 404.
  notFound,

  /// 409: outro cliente reservou o mesmo horário primeiro (ADR-0007).
  conflict,

  /// 502, 503 ou 504: o BFF está no ar, mas o serviço atrás dele não.
  unavailable,

  /// Qualquer outro status.
  unexpected,
}

/// Erro de uma chamada ao BFF. [message] já está em português e pode ir direto para a tela.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  const ApiException.offline()
    : this(
        ApiErrorKind.offline,
        'Sem conexão com o servidor. Confira a internet e se o back-end está no ar.',
      );

  /// Usa o `{"detail": "..."}` do contrato quando ele vem; senão, uma mensagem padrão.
  factory ApiException.fromResponse(int statusCode, String body) {
    final kind = switch (statusCode) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      502 || 503 || 504 => ApiErrorKind.unavailable,
      _ => ApiErrorKind.unexpected,
    };
    final message = _detail(body) ?? _defaultMessage(kind, statusCode);
    return ApiException(kind, message, statusCode: statusCode);
  }

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  static String? _detail(String body) {
    try {
      final json = jsonDecode(body);
      // O 422 do FastAPI traz uma lista em "detail": não serve para a tela.
      final detail = json is Map ? json['detail'] : null;
      if (detail is String) return detail;
    } on FormatException {
      // corpo vazio ou não JSON (ex.: 401 do Spring sem corpo)
    }
    return null;
  }

  static String _defaultMessage(
    ApiErrorKind kind,
    int statusCode,
  ) => switch (kind) {
    ApiErrorKind.offline => const ApiException.offline().message,
    ApiErrorKind.unauthorized => 'Sua sessão expirou. Entre de novo.',
    ApiErrorKind.forbidden => 'Sua conta não tem permissão para isso.',
    ApiErrorKind.notFound => 'Não encontramos o que você procurou.',
    ApiErrorKind.conflict =>
      'Os dados mudaram enquanto você usava o app. Atualize e tente de novo.',
    ApiErrorKind.unavailable =>
      'O serviço está fora do ar. Tente de novo em instantes.',
    ApiErrorKind.unexpected => 'Algo deu errado (HTTP $statusCode).',
  };

  @override
  String toString() => 'ApiException(${kind.name}, $statusCode): $message';
}
