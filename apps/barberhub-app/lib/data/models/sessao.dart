import 'dart:convert';

/// Usuário logado e os tokens que o Keycloak devolveu.
///
/// Fica só na memória (ver ADR.md): fechar o app pede o login de novo.
class Sessao {
  const Sessao({
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEm,
    required this.userId,
    required this.usuario,
    required this.nome,
    required this.roles,
  });

  /// Lê a resposta do endpoint de token. Os dados do usuário saem do próprio access token
  /// (JWT): o app só lê o que está lá para mostrar na tela; quem confere a assinatura é o BFF.
  factory Sessao.fromTokenResponse(
    Map<String, dynamic> json, {
    required DateTime agora,
  }) {
    final accessToken = json['access_token'] as String;
    final claims = _claims(accessToken);
    final realmAccess = claims['realm_access'];
    final roles = realmAccess is Map ? realmAccess['roles'] : null;
    final usuario = claims['preferred_username'] as String? ?? '';
    final nome = (claims['name'] as String? ?? '').trim();
    return Sessao(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      expiraEm: agora.add(Duration(seconds: json['expires_in'] as int)),
      userId: claims['sub'] as String,
      usuario: usuario,
      nome: nome.isEmpty ? usuario : nome,
      roles: roles is List ? roles.whereType<String>().toSet() : const {},
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime expiraEm;

  /// O `sub` do token: é o `cliente_id` que o back-end grava nos agendamentos.
  final String userId;

  /// Login, ex.: `cliente1`.
  final String usuario;

  /// Nome para mostrar, ex.: `Cliente Um`.
  final String nome;

  /// Roles do realm. As do contrato são `cliente` e `gestor`.
  final Set<String> roles;

  bool get ehCliente => roles.contains('cliente');

  bool get ehGestor => roles.contains('gestor');

  /// Verdadeiro quando falta menos que [margem] para o access token vencer.
  bool expiraLogo(
    DateTime agora, {
    Duration margem = const Duration(seconds: 30),
  }) => !agora.add(margem).isBefore(expiraEm);

  static Map<String, dynamic> _claims(String jwt) {
    final partes = jwt.split('.');
    if (partes.length != 3) {
      throw const FormatException('access token não é um JWT');
    }
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(partes[1])),
    );
    return jsonDecode(payload) as Map<String, dynamic>;
  }
}
