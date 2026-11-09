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

/// Rótulo do filtro para as barbearias cujo endereço não diz o bairro.
const semBairro = 'Outros';

/// O bairro de uma barbearia como aparece no filtro.
String bairroDoFiltro(Barbearia barbearia) => barbearia.bairro ?? semBairro;

/// As opções do filtro: os bairros das barbearias carregadas, em ordem alfabética, com
/// [semBairro] por último. Com menos de duas opções não há o que filtrar: devolve vazio.
List<String> bairrosDe(List<Barbearia> barbearias) {
  final bairros = {for (final b in barbearias) bairroDoFiltro(b)};
  if (bairros.length < 2) return const [];
  final temOutros = bairros.remove(semBairro);
  return [
    ...bairros.toList()..sort((a, b) => normalizar(a).compareTo(normalizar(b))),
    if (temOutros) semBairro,
  ];
}

/// As barbearias cujo nome contém [busca] e que ficam em [bairro]. Busca vazia e bairro
/// null não filtram.
///
/// O filtro roda no app: o `GET /barbearias` do contrato não tem parâmetro de busca nem
/// de bairro, e a lista inteira já está na memória.
List<Barbearia> filtrarBarbearias(
  List<Barbearia> barbearias, {
  String busca = '',
  String? bairro,
}) {
  final termo = normalizar(busca);
  if (termo.isEmpty && bairro == null) return barbearias;
  return [
    for (final b in barbearias)
      if ((bairro == null || bairroDoFiltro(b) == bairro) &&
          normalizar(b.nome).contains(termo))
        b,
  ];
}
