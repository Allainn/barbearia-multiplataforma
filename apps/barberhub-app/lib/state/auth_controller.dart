import 'package:flutter/foundation.dart';

import '../data/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/sessao.dart';

/// Quem está logado. A tela de login e a aba Conta escutam; o `BffClient` pede o
/// token por [token] a cada chamada.
class AuthController extends ChangeNotifier {
  AuthController(this._repository, {DateTime Function()? agora})
    : _agora = agora ?? DateTime.now;

  final AuthRepository _repository;
  final DateTime Function() _agora;

  Sessao? _sessao;
  bool _entrando = false;
  ApiException? _erro;
  Future<Sessao?>? _renovacao;

  Sessao? get sessao => _sessao;

  bool get logado => _sessao != null;

  /// Login em andamento: a tela desliga o botão e mostra o progresso.
  bool get entrando => _entrando;

  /// Por que o último login falhou, ou por que a sessão caiu.
  ApiException? get erro => _erro;

  Future<void> entrar(String usuario, String senha) async {
    if (_entrando) return;
    _entrando = true;
    _erro = null;
    notifyListeners();
    try {
      _sessao = await _repository.entrar(usuario.trim(), senha);
    } on ApiException catch (e) {
      _erro = e;
    } finally {
      _entrando = false;
      notifyListeners();
    }
  }

  void sair() {
    _sessao = null;
    _erro = null;
    notifyListeners();
  }

  /// O BFF respondeu 401 a uma chamada feita com [token]: o token deixou de valer antes
  /// de vencer (back-end recriado com chave nova no Keycloak, client sem o mapper de
  /// audience). Renovar não resolve, porque o refresh token vem do mesmo lugar: a sessão
  /// cai e o app volta para o login com o motivo, em vez de prender as telas no erro.
  ///
  /// Um 401 de um token antigo (a resposta chegou depois de um novo login) não derruba a
  /// sessão nova.
  void tokenRecusado(String token) {
    if (_sessao?.accessToken != token) return;
    _sessao = null;
    _erro = const ApiException(
      ApiErrorKind.unauthorized,
      'Sua sessão expirou. Entre de novo.',
    );
    notifyListeners();
  }

  /// Access token válido, ou null se ninguém entrou. É o `TokenProvider` do `BffClient`.
  ///
  /// Perto do vencimento, renova antes de devolver. Se o Keycloak recusar a renovação, a
  /// sessão cai e o app volta para o login; se só faltou rede, o token antigo segue e a
  /// chamada ao BFF mostra o erro de conexão.
  Future<String?> token() async {
    final sessao = _sessao;
    if (sessao == null) return null;
    if (!sessao.expiraLogo(_agora())) return sessao.accessToken;
    // Várias telas pedem o token ao mesmo tempo: todas esperam a mesma renovação.
    final renovada = await (_renovacao ??= _renovar(
      sessao,
    ).whenComplete(() => _renovacao = null));
    return renovada?.accessToken;
  }

  Future<Sessao?> _renovar(Sessao sessao) async {
    final refreshToken = sessao.refreshToken;
    try {
      if (refreshToken == null) {
        throw const ApiException(
          ApiErrorKind.unauthorized,
          'Sua sessão expirou. Entre de novo.',
        );
      }
      final nova = await _repository.renovar(refreshToken);
      if (_sessao == sessao) _sessao = nova; // não ressuscita quem saiu no meio
      return _sessao;
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.unauthorized) return sessao;
      if (_sessao == sessao) {
        _sessao = null;
        _erro = e;
        notifyListeners();
      }
      return null;
    }
  }
}
