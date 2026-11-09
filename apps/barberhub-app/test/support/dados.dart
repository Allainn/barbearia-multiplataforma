// Dados no formato do contrato (docs/tarefas.md), para os testes.
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

/// Back-end falso com a lista de barbearias e o detalhe da Navalha de Ouro no ar.
FakeBackend backendComBarbearias() => FakeBackend(
  rotas: {
    'GET /barbearias': (_) => jsonResponse(barbearias),
    'GET /barbearias/$_idNavalha/profissionais': (_) =>
        jsonResponse([rafael, bruno]),
    'GET /barbearias/$_idNavalha/servicos': (_) =>
        jsonResponse([corteEBarba, corte]),
  },
);
