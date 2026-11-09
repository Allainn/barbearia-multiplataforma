/// Profissional como o `GET /barbearias/{id}/profissionais` devolve.
class Profissional {
  const Profissional({
    required this.id,
    required this.barbeariaId,
    required this.nome,
  });

  factory Profissional.fromJson(Map<String, dynamic> json) => Profissional(
    id: json['id'] as String,
    barbeariaId: json['barbearia_id'] as String,
    nome: json['nome'] as String,
  );

  final String id;
  final String barbeariaId;
  final String nome;

  Map<String, dynamic> toJson() => {
    'id': id,
    'barbearia_id': barbeariaId,
    'nome': nome,
  };

  @override
  bool operator ==(Object other) => other is Profissional && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Profissional($id, $nome)';
}
