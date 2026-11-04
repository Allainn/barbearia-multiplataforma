/// Serviço (corte, barba...) como o `GET /barbearias/{id}/servicos` devolve.
class Servico {
  const Servico({
    required this.id,
    required this.barbeariaId,
    required this.nome,
    required this.duracaoMin,
    required this.preco,
  });

  factory Servico.fromJson(Map<String, dynamic> json) => Servico(
    id: json['id'] as String,
    barbeariaId: json['barbearia_id'] as String,
    nome: json['nome'] as String,
    duracaoMin: json['duracao_min'] as int,
    preco: _preco(json['preco']),
  );

  final String id;
  final String barbeariaId;
  final String nome;
  final int duracaoMin;

  /// Em reais. Para mostrar, use `formatPreco`.
  final double preco;

  Map<String, dynamic> toJson() => {
    'id': id,
    'barbearia_id': barbeariaId,
    'nome': nome,
    'duracao_min': duracaoMin,
    'preco': preco.toStringAsFixed(2),
  };

  // O barbearia-service usa Decimal no Pydantic, que vira texto no JSON ("40.00").
  // Número também é aceito, caso o serviço mude.
  static double _preco(Object? valor) => switch (valor) {
    num n => n.toDouble(),
    String s => double.parse(s),
    _ => throw FormatException('preco inválido: $valor'),
  };

  @override
  bool operator ==(Object other) => other is Servico && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Servico($id, $nome)';
}
