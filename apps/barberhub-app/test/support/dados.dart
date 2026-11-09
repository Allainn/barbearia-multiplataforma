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

/// Back-end falso com a lista de barbearias no ar.
FakeBackend backendComBarbearias() =>
    FakeBackend(rotas: {'GET /barbearias': (_) => jsonResponse(barbearias)});
