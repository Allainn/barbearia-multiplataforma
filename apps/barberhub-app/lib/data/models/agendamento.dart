import '../../core/formatters.dart';
import 'disponibilidade.dart';

enum StatusAgendamento { confirmado, cancelado }

/// Reserva como o `POST /agendamentos` devolve (201).
class Agendamento {
  const Agendamento({
    required this.id,
    required this.barbeariaId,
    required this.profissionalId,
    required this.servicoId,
    required this.clienteId,
    required this.inicio,
    required this.fim,
    required this.status,
  });

  factory Agendamento.fromJson(Map<String, dynamic> json) => Agendamento(
    id: json['id'] as String,
    barbeariaId: json['barbearia_id'] as String,
    profissionalId: json['profissional_id'] as String,
    servicoId: json['servico_id'] as String,
    clienteId: json['cliente_id'] as String,
    inicio: DateTime.parse(json['inicio'] as String),
    fim: DateTime.parse(json['fim'] as String),
    // CONFIRMADO / CANCELADO no contrato
    status: StatusAgendamento.values.byName(
      (json['status'] as String).toLowerCase(),
    ),
  );

  final String id;
  final String barbeariaId;
  final String profissionalId;
  final String servicoId;
  final String clienteId;
  final DateTime inicio;
  final DateTime fim;
  final StatusAgendamento status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'barbearia_id': barbeariaId,
    'profissional_id': profissionalId,
    'servico_id': servicoId,
    'cliente_id': clienteId,
    'inicio': formatInstanteApi(inicio),
    'fim': formatInstanteApi(fim),
    'status': status.name.toUpperCase(),
  };

  @override
  bool operator ==(Object other) => other is Agendamento && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Agendamento($id, ${formatHora(inicio)}, ${status.name})';
}

/// Corpo do `POST /agendamentos`. O cliente vem do token (o BFF manda o `X-User-ID`).
class NovoAgendamento {
  const NovoAgendamento({
    required this.barbeariaId,
    required this.profissionalId,
    required this.servicoId,
    required this.horario,
  });

  final String barbeariaId;
  final String profissionalId;
  final String servicoId;
  final HorarioLivre horario;

  Map<String, Object?> toJson() => {
    'barbearia_id': barbeariaId,
    'profissional_id': profissionalId,
    'servico_id': servicoId,
    ...horario.toJson(),
  };
}
