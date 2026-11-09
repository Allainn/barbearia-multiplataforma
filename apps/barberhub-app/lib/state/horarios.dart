// Regras de horário da tela de reserva, sem widget e sem rede, para dar para testar.
import '../core/formatters.dart';
import '../data/models/disponibilidade.dart';

/// O dia de hoje no calendário da barbearia (pode diferir do dia do aparelho).
DateTime hojeNaBarbearia(DateTime agora) {
  final local = naBarbearia(agora);
  return DateTime(local.year, local.month, local.day);
}

/// Hoje e os próximos dias, para o seletor de dia.
List<DateTime> proximosDias(DateTime agora, {int quantidade = 7}) {
  final hoje = hojeNaBarbearia(agora);
  return [
    for (var i = 0; i < quantidade; i++)
      DateTime(hoje.year, hoje.month, hoje.day + i),
  ];
}

/// "Hoje", "Amanhã" ou `qua., 11 de nov.`.
String rotuloDoDia(DateTime dia, DateTime agora) {
  final hoje = hojeNaBarbearia(agora);
  final distancia = DateTime.utc(
    dia.year,
    dia.month,
    dia.day,
  ).difference(DateTime.utc(hoje.year, hoje.month, hoje.day)).inDays;
  return switch (distancia) {
    0 => 'Hoje',
    1 => 'Amanhã',
    _ => formatDia(dia),
  };
}

/// Os inícios em que cabe um serviço de [duracaoMin] minutos.
///
/// O back-end devolve a grade em blocos livres (30 min). Um serviço de 60 min precisa de
/// dois blocos seguidos; cada resultado já vem com o fim certo para o `POST /agendamentos`.
/// Fica de fora o que já começou ([agora]) e o que encosta num intervalo de [recusados]
/// (horários que o back-end acabou de negar com 409 e a leitura ainda pode mostrar livres).
List<HorarioLivre> horariosParaServico(
  List<HorarioLivre> livres, {
  required int duracaoMin,
  required DateTime agora,
  Iterable<HorarioLivre> recusados = const [],
}) {
  final blocos = [...livres]..sort((a, b) => a.inicio.compareTo(b.inicio));
  final duracao = Duration(minutes: duracaoMin);
  final horarios = <HorarioLivre>[];
  for (var i = 0; i < blocos.length; i++) {
    final inicio = blocos[i].inicio;
    if (!inicio.isAfter(agora)) continue;
    final fim = inicio.add(duracao);
    // anda pelos blocos emendados até cobrir a duração
    var coberto = inicio;
    for (var j = i; j < blocos.length && coberto.isBefore(fim); j++) {
      if (!blocos[j].inicio.isAtSameMomentAs(coberto)) break;
      coberto = blocos[j].fim;
    }
    if (coberto.isBefore(fim)) continue;
    final candidato = HorarioLivre(inicio: inicio, fim: fim);
    if (recusados.any((r) => _sobrepoe(candidato, r))) continue;
    horarios.add(candidato);
  }
  return horarios;
}

bool _sobrepoe(HorarioLivre a, HorarioLivre b) =>
    a.inicio.isBefore(b.fim) && b.inicio.isBefore(a.fim);
