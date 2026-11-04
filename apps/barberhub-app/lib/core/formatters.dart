// Formatação para a tela e para a API, em português e no fuso das barbearias.
//
// O contrato manda os horários com offset -03:00 (America/Sao_Paulo, sem horário de verão
// desde 2019). `DateTime.parse` guarda o instante em UTC; se a tela usasse `toLocal()`, um
// emulador em UTC mostraria 13:00 no lugar de 10:00. Por isso as horas passam por
// [naBarbearia], que não depende do fuso do aparelho.

/// Offset fixo das barbearias.
const fusoBarbearia = Duration(hours: -3);

const _diasDaSemana = ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'];
const _meses = [
  'jan.',
  'fev.',
  'mar.',
  'abr.',
  'mai.',
  'jun.',
  'jul.',
  'ago.',
  'set.',
  'out.',
  'nov.',
  'dez.',
];

/// O relógio da parede da barbearia para um instante (os campos ano...minuto já em -03:00).
DateTime naBarbearia(DateTime instante) => instante.toUtc().add(fusoBarbearia);

/// `10:00`.
String formatHora(DateTime instante) {
  final local = naBarbearia(instante);
  return '${_doisDigitos(local.hour)}:${_doisDigitos(local.minute)}';
}

/// `seg., 9 de nov.` para uma data do calendário (ex.: o `data` da disponibilidade).
/// Para um instante, passe `naBarbearia(instante)`.
String formatDia(DateTime dia) =>
    '${_diasDaSemana[dia.weekday - 1]}, ${dia.day} de ${_meses[dia.month - 1]}';

/// `R$ 1.250,00`.
String formatPreco(num valor) {
  final centavos = (valor * 100).round();
  final reais = (centavos ~/ 100).toString();
  final milhares = reais.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => '.',
  );
  return 'R\$ $milhares,${_doisDigitos(centavos % 100)}';
}

/// `30 min`, `1 h`, `1 h 15 min`.
String formatDuracao(int minutos) {
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  if (horas == 0) return '$resto min';
  return resto == 0 ? '$horas h' : '$horas h $resto min';
}

/// `2026-11-09`, o formato do parâmetro `data` do `GET /disponibilidade`.
String formatDataApi(DateTime dia) =>
    '${dia.year}-${_doisDigitos(dia.month)}-${_doisDigitos(dia.day)}';

/// `2026-11-09T10:00:00-03:00`, o formato do `inicio`/`fim` do `POST /agendamentos`.
String formatInstanteApi(DateTime instante) {
  final local = naBarbearia(instante);
  return '${formatDataApi(local)}T${_doisDigitos(local.hour)}:'
      '${_doisDigitos(local.minute)}:${_doisDigitos(local.second)}-03:00';
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');
