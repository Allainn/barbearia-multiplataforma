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

  /// O bairro, quando o endereço segue o formato "Rua, número - Bairro" (o do seed do
  /// app). O contrato não tem campo de bairro: endereço fora do formato devolve null.
  String? get bairro {
    final i = endereco.lastIndexOf(' - ');
    if (i < 0) return null;
    final bairro = endereco.substring(i + 3).split(',').first.trim();
    return bairro.isEmpty ? null : bairro;
  }

  /// O endereço sem o bairro: "Av. Getúlio Vargas, 1420".
  String get logradouro {
    if (bairro == null) return endereco;
    return endereco.substring(0, endereco.lastIndexOf(' - ')).trim();
  }

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
