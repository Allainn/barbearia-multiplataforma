import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_config.dart';
import 'data/agendamento_repository.dart';
import 'data/auth_repository.dart';
import 'data/barbearia_repository.dart';
import 'data/bff_client.dart';
import 'data/disponibilidade_repository.dart';
import 'data/favoritos_repository.dart';
import 'data/reservas_local_repository.dart';
import 'state/agendamentos_controller.dart';
import 'state/auth_controller.dart';
import 'state/barbearias_controller.dart';
import 'state/favoritos_controller.dart';
import 'state/theme_controller.dart';

/// Raiz de composição: monta repositórios e controllers uma vez e entrega para as telas.
///
/// Sem biblioteca de estado (ADR.md), as dependências descem pelo construtor. Este objeto
/// evita que cada tela no caminho precise repassar uma lista de parâmetros.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.bffClient,
    required this.auth,
    required this.theme,
    required this.barbeariaRepository,
    required this.disponibilidadeRepository,
    required this.agendamentoRepository,
    required this.barbearias,
    required this.favoritos,
    required this.agendamentos,
  });

  /// [httpClient] entra nos testes (um `MockClient` no lugar da rede).
  factory AppDependencies.create({
    required AppConfig config,
    required SharedPreferences prefs,
    http.Client? httpClient,
  }) {
    final auth = AuthController(
      AuthRepository(
        tokenUrl: config.tokenUrl,
        clientId: config.clientId,
        httpClient: httpClient,
      ),
    );
    final bffClient = BffClient(
      baseUrl: config.bffUrl,
      tokenProvider: auth.token,
      onUnauthorized: auth.tokenRecusado,
      httpClient: httpClient,
    );
    final barbeariaRepository = BarbeariaRepository(bffClient);
    final agendamentoRepository = AgendamentoRepository(bffClient);
    return AppDependencies._(
      config: config,
      bffClient: bffClient,
      auth: auth,
      theme: ThemeController(prefs),
      barbeariaRepository: barbeariaRepository,
      disponibilidadeRepository: DisponibilidadeRepository(bffClient),
      agendamentoRepository: agendamentoRepository,
      barbearias: BarbeariasController(barbeariaRepository),
      favoritos: FavoritosController(FavoritosRepository(prefs)),
      agendamentos: AgendamentosController(
        ReservasLocalRepository(prefs),
        agendamentoRepository,
      ),
    );
  }

  final AppConfig config;
  final BffClient bffClient;
  final AuthController auth;
  final ThemeController theme;
  final BarbeariaRepository barbeariaRepository;
  final DisponibilidadeRepository disponibilidadeRepository;
  final AgendamentoRepository agendamentoRepository;
  final BarbeariasController barbearias;
  final FavoritosController favoritos;
  final AgendamentosController agendamentos;
}
