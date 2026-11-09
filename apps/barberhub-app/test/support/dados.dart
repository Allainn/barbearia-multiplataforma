// Dados no formato do contrato (docs/tarefas.md), para os testes.
import 'dart:convert';

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

/// Back-end falso com a lista de barbearias, o detalhe da Navalha de Ouro, a grade de
/// horários e a reserva no ar.
FakeBackend backendComBarbearias() => FakeBackend(
  rotas: {
    'GET /barbearias': (_) => jsonResponse(barbearias),
    'GET /barbearias/$_idNavalha/profissionais': (_) =>
        jsonResponse([rafael, bruno]),
    'GET /barbearias/$_idNavalha/servicos': (_) =>
        jsonResponse([corteEBarba, corte]),
    'GET /disponibilidade': gradeDoDia,
    'POST /agendamentos': agendamentoCriado,
  },
);
