/// Barbearia como o `GET /barbearias` devolve.
class Barbearia {
  const Barbearia({
    required this.id,
    required this.nome,
    required this.endereco,
  });

  factory Barbearia.fromJson(Map<String, dynamic> json) => Barbearia(
    id: json['id'] as String,
    nome: json['nome'] as String,
    endereco: json['endereco'] as String,
  );

  final String id;
  final String nome;
  final String endereco;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'endereco': endereco,
  };

  /// Mesma barbearia = mesmo id (os dados podem ter mudado no servidor).
  @override
  bool operator ==(Object other) => other is Barbearia && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Barbearia($id, $nome)';
}
