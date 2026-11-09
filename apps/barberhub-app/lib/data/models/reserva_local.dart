import 'agendamento.dart';

/// Uma reserva feita neste aparelho, como a aba Agendamentos mostra.
///
/// O [Agendamento] do contrato só tem ids, e o back-end não tem rota para listar as
/// reservas do cliente. Por isso o app guarda, junto com a resposta do `POST /agendamentos`,
/// os nomes que estavam na tela na hora da reserva.
class ReservaLocal {
  const ReservaLocal({
    required this.agendamento,
    required this.barbeariaNome,
    required this.profissionalNome,
    required this.servicoNome,
    required this.preco,
  });

  factory ReservaLocal.fromJson(Map<String, dynamic> json) => ReservaLocal(
    agendamento: Agendamento.fromJson(
      json['agendamento'] as Map<String, dynamic>,
    ),
    barbeariaNome: json['barbearia_nome'] as String,
    profissionalNome: json['profissional_nome'] as String,
    servicoNome: json['servico_nome'] as String,
    preco: (json['preco'] as num).toDouble(),
  );

  final Agendamento agendamento;
  final String barbeariaNome;
  final String profissionalNome;
  final String servicoNome;

  /// Em reais, o preço do serviço na hora da reserva.
  final double preco;

  String get id => agendamento.id;

  bool get cancelada => agendamento.status == StatusAgendamento.cancelado;

  /// Confirmada e ainda não terminou.
  bool ativaEm(DateTime agora) => !cancelada && agendamento.fim.isAfter(agora);

  ReservaLocal comoCancelada() => ReservaLocal(
    agendamento: agendamento.comoCancelado(),
    barbeariaNome: barbeariaNome,
    profissionalNome: profissionalNome,
    servicoNome: servicoNome,
    preco: preco,
  );

  Map<String, dynamic> toJson() => {
    'agendamento': agendamento.toJson(),
    'barbearia_nome': barbeariaNome,
    'profissional_nome': profissionalNome,
    'servico_nome': servicoNome,
    'preco': preco,
  };
}
