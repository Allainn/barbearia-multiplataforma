// Dados no formato do contrato (docs/tarefas.md), para os testes.
import 'dart:convert';

import 'package:barberhub_app/core/formatters.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';

const barbeariaCentro = {
  'id': '11111111-1111-1111-1111-111111111111',
  'nome': 'Barbearia Centro',
  'endereco': 'Rua da Bahia 1000',
};

const navalhaDeOuro = {
  'id': 'aaaaaaaa-0000-0000-0000-000000000001',
  'nome': 'Navalha de Ouro',
  'endereco': 'Av. Getúlio Vargas, 1420 - Savassi',
};

const savassiClassica = {
  'id': 'aaaaaaaa-0000-0000-0000-000000000002',
  'nome': 'Savassi Clássica',
  'endereco': 'Rua Pernambuco, 1000 - Savassi',
};

const domBigode = {
  'id': 'aaaaaaaa-0000-0000-0000-000000000003',
  'nome': 'Dom Bigode',
  'endereco': 'Rua Curitiba, 2202 - Lourdes',
};

/// Fora de ordem de propósito: quem ordena é o repositório.
const barbearias = [navalhaDeOuro, barbeariaCentro, savassiClassica, domBigode];

const rafael = {
  'id': 'bbbbbbbb-0000-0000-0000-000000000001',
  'barbearia_id': 'aaaaaaaa-0000-0000-0000-000000000001',
  'nome': 'Rafael',
};

const bruno = {
  'id': 'bbbbbbbb-0000-0000-0000-000000000002',
  'barbearia_id': 'aaaaaaaa-0000-0000-0000-000000000001',
  'nome': 'Bruno',
};

/// O preço vem como texto: o barbearia-service usa Decimal.
const corte = {
  'id': 'cccccccc-0000-0000-0000-000000000001',
  'barbearia_id': 'aaaaaaaa-0000-0000-0000-000000000001',
  'nome': 'Corte',
  'duracao_min': 30,
  'preco': '55.00',
};

const corteEBarba = {
  'id': 'cccccccc-0000-0000-0000-000000000002',
  'barbearia_id': 'aaaaaaaa-0000-0000-0000-000000000001',
  'nome': 'Corte e barba',
  'duracao_min': 60,
  'preco': '85.00',
};

final _idNavalha = navalhaDeOuro['id'];

/// A grade do disponibilidade-service: blocos de 30 min das 09:00 às 18:00 do dia pedido
/// em `data`, menos os que começam em [ocupados] (ex.: `{'10:00'}`).
http.Response gradeDoDia(
  http.Request request, {
  Set<String> ocupados = const {},
}) {
  final data = request.url.queryParameters['data']!;
  String hora(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';
  return jsonResponse({
    'profissional_id': request.url.queryParameters['profissional_id'],
    'data': data,
    'horarios_livres': [
      for (var m = 9 * 60; m < 18 * 60; m += 30)
        if (!ocupados.contains(hora(m)))
          {
            'inicio': '${data}T${hora(m)}:00-03:00',
            'fim': '${data}T${hora(m + 30)}:00-03:00',
          },
    ],
  });
}

/// O `POST /agendamentos` do contrato: devolve 201 com o que recebeu, mais id, cliente e
/// status.
http.Response agendamentoCriado(http.Request request, {String id = 'ag-1'}) {
  final corpo = jsonDecode(request.body) as Map<String, dynamic>;
  return jsonResponse({
    ...corpo,
    'id': id,
    'cliente_id': 'id-cliente1',
    'status': 'CONFIRMADO',
  }, 201);
}

/// Um agendamento no formato do contrato (o 201 do `POST` e cada item do `GET`), na
/// Navalha de Ouro com o Rafael fazendo um corte de 30 min, se nada mudar.
Map<String, dynamic> agendamentoJson(
  String id, {
  required String inicio,
  String cliente = 'id-cliente1',
  String status = 'CONFIRMADO',
  String? barbeariaId,
  String? profissionalId,
  String? servicoId,
}) {
  final fim = DateTime.parse(inicio).add(const Duration(minutes: 30));
  return {
    'id': id,
    'barbearia_id': barbeariaId ?? navalhaDeOuro['id'],
    'profissional_id': profissionalId ?? rafael['id'],
    'servico_id': servicoId ?? corte['id'],
    'cliente_id': cliente,
    'inicio': inicio,
    'fim': formatInstanteApi(fim),
    'status': status,
  };
}

/// O agendamento-service de mentira, com estado: o `POST` guarda, o `GET` devolve (do que
/// começa mais tarde para o mais cedo, como o contrato) e o [cancelar] muda o status.
class AgendamentosNoServidor {
  /// Os agendamentos no formato do contrato. O teste pode pôr ou tirar itens direto
  /// (ex.: uma reserva feita em outro aparelho, ou o ambiente recriado).
  final itens = <Map<String, dynamic>>[];

  http.Response listar(http.Request _) => jsonResponse(
    [...itens]..sort(
      (a, b) => DateTime.parse(
        b['inicio'] as String,
      ).compareTo(DateTime.parse(a['inicio'] as String)),
    ),
  );

  /// Ids `ag-1`, `ag-2`... na ordem das reservas.
  http.Response criar(http.Request request) {
    final resposta = agendamentoCriado(request, id: 'ag-${itens.length + 1}');
    itens.add(
      jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>,
    );
    return resposta;
  }

  /// A rota `DELETE /agendamentos/[id]`: 204, ou 404 se o agendamento não está aqui.
  Rota cancelar(String id) => (_) {
    final item = [
      for (final i in itens)
        if (i['id'] == id) i,
    ];
    if (item.isEmpty) {
      return jsonResponse({'detail': 'Agendamento não encontrado'}, 404);
    }
    item.single['status'] = 'CANCELADO';
    return http.Response('', 204);
  };
}

/// Back-end falso com a lista de barbearias, o detalhe da Navalha de Ouro, a grade de
/// horários e o agendamento-service ([servidor], que começa vazio) no ar.
FakeBackend backendComBarbearias({AgendamentosNoServidor? servidor}) {
  final agendamentos = servidor ?? AgendamentosNoServidor();
  return FakeBackend(
    rotas: {
      'GET /barbearias': (_) => jsonResponse(barbearias),
      'GET /barbearias/$_idNavalha/profissionais': (_) =>
          jsonResponse([rafael, bruno]),
      'GET /barbearias/$_idNavalha/servicos': (_) =>
          jsonResponse([corteEBarba, corte]),
      'GET /disponibilidade': gradeDoDia,
      'GET /agendamentos': agendamentos.listar,
      'POST /agendamentos': agendamentos.criar,
    },
  );
}
