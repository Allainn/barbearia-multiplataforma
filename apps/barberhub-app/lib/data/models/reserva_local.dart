import 'agendamento.dart';

/// Uma reserva como a aba Agendamentos mostra: o [Agendamento] do servidor com os nomes
/// que ele não traz.
///
/// O contrato do `GET /agendamentos` só tem ids. Os nomes vêm de dois lugares: do que
/// estava na tela na hora da reserva (guardado no aparelho junto com a resposta do
/// `POST /agendamentos`) ou, para reserva feita em outro aparelho, do catálogo de
/// barbearias (`CatalogoNomes`). O status e a existência da reserva vêm sempre do
/// servidor; o aparelho é só o cache dos nomes (ver ADR.md).
class ReservaLocal {
  const ReservaLocal({
    required this.agendamento,
    required this.barbeariaNome,
    required this.profissionalNome,
    required this.servicoNome,
    required this.preco,
  });

  /// Reserva do servidor de que o app não sabe nenhum nome.
  const ReservaLocal.semNomes(this.agendamento)
    : barbeariaNome = null,
      profissionalNome = null,
      servicoNome = null,
      preco = null;

  // Campos ausentes ou null: reserva que veio do servidor sem nome resolvido. Cache
  // antigo sempre tem os quatro, então continua sendo lido igual.
  factory ReservaLocal.fromJson(Map<String, dynamic> json) => ReservaLocal(
    agendamento: Agendamento.fromJson(
      json['agendamento'] as Map<String, dynamic>,
    ),
    barbeariaNome: json['barbearia_nome'] as String?,
    profissionalNome: json['profissional_nome'] as String?,
    servicoNome: json['servico_nome'] as String?,
    preco: (json['preco'] as num?)?.toDouble(),
  );

  final Agendamento agendamento;

  /// Null quando não deu para resolver o nome (rede, ou item apagado do catálogo): a
  /// tela mostra um texto neutro e a próxima carga tenta de novo.
  final String? barbeariaNome;
  final String? profissionalNome;
  final String? servicoNome;

  /// Em reais, o preço do serviço na hora da reserva (ou o atual do catálogo, para
  /// reserva feita em outro aparelho).
  final double? preco;

  String get id => agendamento.id;

  bool get cancelada => agendamento.status == StatusAgendamento.cancelado;

  /// Falta algum nome: vale perguntar ao catálogo de novo.
  bool get incompleta =>
      barbeariaNome == null ||
      profissionalNome == null ||
      servicoNome == null ||
      preco == null;

  /// Confirmada e ainda não terminou.
  bool ativaEm(DateTime agora) => !cancelada && agendamento.fim.isAfter(agora);

  /// Os nomes desta reserva com o [agendamento] que o servidor mandou agora (status e
  /// horário do servidor ganham do que estava guardado).
  ReservaLocal com(Agendamento agendamento) => ReservaLocal(
    agendamento: agendamento,
    barbeariaNome: barbeariaNome,
    profissionalNome: profissionalNome,
    servicoNome: servicoNome,
    preco: preco,
  );

  /// Junta os nomes desta com os de [outra], preferindo os desta.
  ReservaLocal completadaCom(ReservaLocal outra) => ReservaLocal(
    agendamento: agendamento,
    barbeariaNome: barbeariaNome ?? outra.barbeariaNome,
    profissionalNome: profissionalNome ?? outra.profissionalNome,
    servicoNome: servicoNome ?? outra.servicoNome,
    preco: preco ?? outra.preco,
  );

  ReservaLocal comoCancelada() => com(agendamento.comoCancelado());

  Map<String, dynamic> toJson() => {
    'agendamento': agendamento.toJson(),
    'barbearia_nome': barbeariaNome,
    'profissional_nome': profissionalNome,
    'servico_nome': servicoNome,
    'preco': preco,
  };
}
