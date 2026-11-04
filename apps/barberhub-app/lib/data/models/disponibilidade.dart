import '../../core/formatters.dart';

/// Um horário livre de um profissional. [inicio] e [fim] são instantes (guardados em UTC);
/// para mostrar, use `formatHora`.
class HorarioLivre {
  const HorarioLivre({required this.inicio, required this.fim});

  factory HorarioLivre.fromJson(Map<String, dynamic> json) => HorarioLivre(
    inicio: DateTime.parse(json['inicio'] as String),
    fim: DateTime.parse(json['fim'] as String),
  );

  final DateTime inicio;
  final DateTime fim;

  Map<String, dynamic> toJson() => {
    'inicio': formatInstanteApi(inicio),
    'fim': formatInstanteApi(fim),
  };

  @override
  bool operator ==(Object other) =>
      other is HorarioLivre &&
      other.inicio.isAtSameMomentAs(inicio) &&
      other.fim.isAtSameMomentAs(fim);

  @override
  int get hashCode =>
      Object.hash(inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch);

  @override
  String toString() => 'HorarioLivre(${formatHora(inicio)}–${formatHora(fim)})';
}

/// Resposta do `GET /disponibilidade?profissional_id=...&data=AAAA-MM-DD`.
class Disponibilidade {
  const Disponibilidade({
    required this.profissionalId,
    required this.data,
    required this.horariosLivres,
  });

  factory Disponibilidade.fromJson(Map<String, dynamic> json) {
    final [ano, mes, dia] = (json['data'] as String)
        .split('-')
        .map(int.parse)
        .toList();
    return Disponibilidade(
      profissionalId: json['profissional_id'] as String,
      data: DateTime(ano, mes, dia),
      horariosLivres: (json['horarios_livres'] as List)
          .map((h) => HorarioLivre.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  final String profissionalId;

  /// Só a data do calendário (meia-noite local); para mostrar, use `formatDia`.
  final DateTime data;

  final List<HorarioLivre> horariosLivres;
}
