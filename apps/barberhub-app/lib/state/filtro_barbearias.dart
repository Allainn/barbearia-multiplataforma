import '../data/models/barbearia.dart';

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

/// Minúsculas, sem acento e sem espaço sobrando: "  São José " → "sao jose".
/// Assim "savassi classica" encontra "Savassi Clássica".
String normalizar(String texto) {
  final saida = StringBuffer();
  for (final letra in texto.trim().toLowerCase().split('')) {
    final i = _comAcento.indexOf(letra);
    saida.write(i < 0 ? letra : _semAcento[i]);
  }
  return saida.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// As barbearias cujo nome contém [busca]. Busca vazia devolve todas.
///
/// O filtro roda no app: o `GET /barbearias` do contrato não tem parâmetro de busca, e a
/// lista inteira já está na memória.
List<Barbearia> filtrarBarbearias(
  List<Barbearia> barbearias, {
  String busca = '',
}) {
  final termo = normalizar(busca);
  if (termo.isEmpty) return barbearias;
  return [
    for (final b in barbearias)
      if (normalizar(b.nome).contains(termo)) b,
  ];
}
