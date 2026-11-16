import 'barbearia_repository.dart';
import 'models/agendamento.dart';
import 'models/reserva_local.dart';

/// Dá nome aos ids de um [Agendamento] que veio do servidor e não está no cache do
/// aparelho (reservado em outro celular, ou pelo `curl`).
///
/// O contrato do `GET /agendamentos` só tem ids. Em vez de uma rota nova no BFF, o app
/// reaproveita o catálogo que já existe: um `GET /barbearias` e, para cada barbearia
/// diferente, os profissionais e os serviços. São chamadas por barbearia, e não por
/// agendamento: dez reservas na mesma barbearia custam as mesmas três chamadas.
class CatalogoNomes {
  CatalogoNomes(this._barbearias);

  final BarbeariaRepository _barbearias;

  /// Uma [ReservaLocal] por agendamento, na mesma ordem. O que não deu para resolver
  /// (rede caiu, barbearia ou serviço apagado) fica null, e a tela mostra um texto
  /// neutro: um nome que falta não pode esconder a reserva.
  Future<List<ReservaLocal>> resolver(List<Agendamento> agendamentos) async {
    if (agendamentos.isEmpty) return const [];
    Map<String, String> nomesBarbearia;
    try {
      nomesBarbearia = {
        for (final b in await _barbearias.listar()) b.id: b.nome,
      };
    } on Object {
      nomesBarbearia = const {};
    }
    final ids = {for (final a in agendamentos) a.barbeariaId};
    final detalhes = {
      for (final (id, detalhe) in await Future.wait([
        for (final id in ids) _detalhe(id).then((d) => (id, d)),
      ]))
        id: detalhe,
    };
    return [
      for (final a in agendamentos)
        _reserva(a, nomesBarbearia[a.barbeariaId], detalhes[a.barbeariaId]!),
    ];
  }

  /// Profissionais e serviços de uma barbearia. Cada lista falha sozinha: sem os
  /// serviços, o nome do profissional ainda aparece.
  Future<_Detalhe> _detalhe(String barbeariaId) async {
    final (profissionais, servicos) = await (
      _barbearias
          .profissionais(barbeariaId)
          .then<Map<String, String>>((l) => {for (final p in l) p.id: p.nome})
          .catchError((Object _) => const <String, String>{}),
      _barbearias
          .servicos(barbeariaId)
          .then<Map<String, (String, double)>>(
            (l) => {for (final s in l) s.id: (s.nome, s.preco)},
          )
          .catchError((Object _) => const <String, (String, double)>{}),
    ).wait;
    return _Detalhe(profissionais, servicos);
  }

  ReservaLocal _reserva(Agendamento a, String? barbearia, _Detalhe detalhe) {
    final servico = detalhe.servicos[a.servicoId];
    return ReservaLocal(
      agendamento: a,
      barbeariaNome: barbearia,
      profissionalNome: detalhe.profissionais[a.profissionalId],
      servicoNome: servico?.$1,
      preco: servico?.$2,
    );
  }
}

class _Detalhe {
  const _Detalhe(this.profissionais, this.servicos);

  final Map<String, String> profissionais;
  final Map<String, (String, double)> servicos;
}
