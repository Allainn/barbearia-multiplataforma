// Gera as imagens de docs/screenshots/ a partir das telas de verdade, com o back-end falso
// dos testes e as fontes do app. Não roda no `flutter test` normal (fica fora de test/):
//
//   flutter test tool/screenshots_test.dart
//
// Serve para o README ter imagens atualizadas mesmo numa máquina sem emulador. Não é
// teste: não confere nada, só desenha e salva.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:barberhub_app/app.dart';
import 'package:barberhub_app/app_dependencies.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../test/support/dados.dart';
import '../test/support/fake_backend.dart';
import '../test/support/pump_app.dart';

const _pasta = 'docs/screenshots';
const _tela = Size(412, 892); // um Android comum, em pontos
const _densidade = 2.0;

Map<String, String> _barbearia(int n, String nome, String endereco) => {
  'id': 'aaaaaaaa-0000-0000-0000-${n.toString().padLeft(12, '0')}',
  'nome': nome,
  'endereco': endereco,
};

final _lista = [
  navalhaDeOuro,
  savassiClassica,
  domBigode,
  _barbearia(4, 'Tesoura Central', 'Rua dos Carijós, 244 - Centro'),
  _barbearia(5, 'Barba & Brasa', 'Av. Fleming, 394 - Pampulha'),
  _barbearia(6, 'Corte Mineiro', 'Rua Pium-í, 611 - Sion'),
  _barbearia(7, 'Velha Guarda', 'Av. Afonso Pena, 3111 - Funcionários'),
];

FakeBackend _backend() {
  final id = navalhaDeOuro['id'];
  Map<String, Object> servico(int n, String nome, int duracao, String preco) =>
      {
        'id': 'cccccccc-0000-0000-0000-00000000000$n',
        'barbearia_id': id!,
        'nome': nome,
        'duracao_min': duracao,
        'preco': preco,
      };
  return FakeBackend(
    rotas: {
      'GET /barbearias': (_) => jsonResponse(_lista),
      'GET /barbearias/$id/profissionais': (_) => jsonResponse([
        rafael,
        bruno,
        {
          ...bruno,
          'id': 'bbbbbbbb-0000-0000-0000-000000000003',
          'nome': 'Tiago',
        },
      ]),
      'GET /barbearias/$id/servicos': (_) => jsonResponse([
        servico(1, 'Corte', 30, '55.00'),
        servico(2, 'Barba', 30, '40.00'),
        servico(3, 'Corte e barba', 60, '85.00'),
        servico(4, 'Pigmentação', 60, '120.00'),
      ]),
      'GET /disponibilidade': (r) => gradeDoDia(
        r,
        ocupados: {'09:30', '11:00', '14:00', '14:30', '16:00'},
      ),
      'POST /agendamentos': agendamentoCriado,
      'DELETE /agendamentos/ag-1': (_) => http.Response('', 204),
    },
  );
}

Future<void> _carregarFontes() async {
  Future<void> familia(String nome, List<String> arquivos) async {
    final loader = FontLoader(nome);
    for (final arquivo in arquivos) {
      loader.addFont(
        File(arquivo).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  await familia('Manrope', [
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Manrope-$peso.ttf',
  ]);
  await familia('DM Serif Display', [
    'assets/fonts/DMSerifDisplay-Regular.ttf',
  ]);
  await familia('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
  ]);
}

final _moldura = GlobalKey();

Future<AppDependencies> _abrir(
  WidgetTester tester, {
  bool escuro = false,
  FakeBackend? backend,
}) async {
  tester.view.physicalSize = _tela * _densidade;
  tester.view.devicePixelRatio = _densidade;
  addTearDown(tester.view.reset);
  final deps = await criarDependencias(backend ?? _backend());
  if (escuro) await deps.theme.setMode(ThemeMode.dark);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _moldura,
      child: BarberHubApp(dependencies: deps),
    ),
  );
  return deps;
}

Future<void> _salvar(WidgetTester tester, String nome) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_moldura),
  );
  await tester.runAsync(() async {
    final imagem = await boundary.toImage(pixelRatio: _densidade);
    final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
    File('$_pasta/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _irParaReserva(WidgetTester tester) async {
  await tester.tap(find.text('Navalha de Ouro'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reservar horário'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, 'Amanhã'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(ChoiceChip, 'Corte e barba · R\$ 85,00'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _carregarFontes();
    Directory(_pasta).createSync(recursive: true);
  });
  // os testes trocam sombra por contorno; a imagem do README quer a sombra de verdade
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  testWidgets('login', (tester) async {
    await _abrir(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuário'),
      'cliente1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'cliente123',
    );
    await tester.pumpAndSettle();
    await _salvar(tester, '01-login');
    debugDisableShadows = true;
  });

  testWidgets('lista, busca e filtro', (tester) async {
    final deps = await _abrir(tester);
    await deps.favoritos.alternar(Barbearia.fromJson(domBigode));
    await entrarComo(tester, 'cliente1', 'cliente123');
    await _salvar(tester, '02-lista');

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Savassi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Savassi'));
    await tester.pumpAndSettle();
    await _salvar(tester, '03-filtro');

    await tester.enterText(find.byType(TextField), 'pizzaria');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _salvar(tester, '04-busca-vazia');
    debugDisableShadows = true;
  });

  testWidgets('detalhe, reserva e agendamentos', (tester) async {
    await _abrir(tester);
    await entrarComo(tester, 'cliente1', 'cliente123');
    await tester.tap(find.text('Navalha de Ouro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritar').hitTestable());
    await tester.pumpAndSettle();
    await _salvar(tester, '05-detalhe');
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await _irParaReserva(tester);
    await _salvar(tester, '06-reserva');

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await tester.pumpAndSettle();
    await _salvar(tester, '07-confirmada');
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();
    await _salvar(tester, '08-agendamentos');

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    await _salvar(tester, '09-favoritos');
    debugDisableShadows = true;
  });

  testWidgets('disputa de horário (409)', (tester) async {
    final backend = _backend();
    await _abrir(tester, backend: backend);
    await entrarComo(tester, 'cliente1', 'cliente123');
    await _irParaReserva(tester);
    // outro cliente confirma primeiro: o BFF devolve o 409 do agendamento-service
    backend.rotas['POST /agendamentos'] = (_) => jsonResponse({
      'detail': 'Horário indisponível para este profissional',
    }, 409);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await tester.pumpAndSettle();
    await _salvar(tester, '10-disputa-409');
    debugDisableShadows = true;
  });

  testWidgets('tema escuro e sem conexão', (tester) async {
    final backend = _backend();
    await _abrir(tester, escuro: true, backend: backend);
    await entrarComo(tester, 'cliente1', 'cliente123');
    await _salvar(tester, '11-lista-escuro');

    await tester.tap(find.text('Navalha de Ouro'));
    await tester.pumpAndSettle();
    await _salvar(tester, '12-detalhe-escuro');
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    // sem rede ao puxar para atualizar: a lista dá lugar ao estado de erro
    backend.rotas['GET /barbearias'] = (request) =>
        throw http.ClientException('sem rede', request.url);
    await tester.drag(find.text('Dom Bigode'), const Offset(0, 400));
    await tester.pumpAndSettle();
    await _salvar(tester, '13-sem-conexao-escuro');
    debugDisableShadows = true;
  });
}
