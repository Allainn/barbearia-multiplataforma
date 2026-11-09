import 'package:barberhub_app/data/models/disponibilidade.dart';
import 'package:barberhub_app/state/horarios.dart';
import 'package:barberhub_app/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bloco de 30 min começando em [hora] (`'10:00'`) de 10/11/2026, no fuso da barbearia.
HorarioLivre _bloco(String hora) {
  final inicio = DateTime.parse('2026-11-10T$hora:00-03:00');
  return HorarioLivre(
    inicio: inicio,
    fim: inicio.add(const Duration(minutes: 30)),
  );
}

List<String> _horas(List<HorarioLivre> horarios) => [
  for (final h in horarios) '${formatHora(h.inicio)}-${formatHora(h.fim)}',
];

final _antesDeAbrir = DateTime.parse('2026-11-10T08:00:00-03:00');

void main() {
  group('horariosParaServico', () {
    test('serviço de 30 min: um horário por bloco livre', () {
      final horarios = horariosParaServico(
        [_bloco('09:00'), _bloco('09:30'), _bloco('11:00')],
        duracaoMin: 30,
        agora: _antesDeAbrir,
      );
      expect(_horas(horarios), ['09:00-09:30', '09:30-10:00', '11:00-11:30']);
    });

    test('serviço de 60 min precisa de dois blocos seguidos', () {
      final horarios = horariosParaServico(
        // 10:00 ocupado: 09:30 não cabe; 17:30 é o último bloco e não tem o seguinte
        [
          _bloco('09:00'),
          _bloco('09:30'),
          _bloco('10:30'),
          _bloco('11:00'),
          _bloco('17:30'),
        ],
        duracaoMin: 60,
        agora: _antesDeAbrir,
      );
      expect(_horas(horarios), ['09:00-10:00', '10:30-11:30']);
    });

    test('o que já começou fica de fora', () {
      final horarios = horariosParaServico(
        [_bloco('09:00'), _bloco('09:30'), _bloco('10:00')],
        duracaoMin: 30,
        agora: DateTime.parse('2026-11-10T09:30:00-03:00'),
      );
      expect(_horas(horarios), ['10:00-10:30']);
    });

    test('horário recusado com 409 some, e leva junto quem encosta nele', () {
      final recusado = HorarioLivre(
        inicio: DateTime.parse('2026-11-10T10:00:00-03:00'),
        fim: DateTime.parse('2026-11-10T10:30:00-03:00'),
      );
      final livres = [
        _bloco('09:30'),
        _bloco('10:00'),
        _bloco('10:30'),
        _bloco('11:00'),
      ];

      expect(
        _horas(
          horariosParaServico(
            livres,
            duracaoMin: 30,
            agora: _antesDeAbrir,
            recusados: [recusado],
          ),
        ),
        ['09:30-10:00', '10:30-11:00', '11:00-11:30'],
      );
      // com 60 min, começar 09:30 passaria por cima do 10:00 recusado
      expect(
        _horas(
          horariosParaServico(
            livres,
            duracaoMin: 60,
            agora: _antesDeAbrir,
            recusados: [recusado],
          ),
        ),
        ['10:30-11:30'],
      );
    });

    test('aceita a grade fora de ordem', () {
      final horarios = horariosParaServico(
        [_bloco('09:30'), _bloco('09:00')],
        duracaoMin: 60,
        agora: _antesDeAbrir,
      );
      expect(_horas(horarios), ['09:00-10:00']);
    });
  });

  group('dias do seletor', () {
    test('o dia é o da barbearia, mesmo com o aparelho já no dia seguinte', () {
      // 01:00 UTC de 10/11 ainda é 22:00 de 09/11 em Belo Horizonte
      final agora = DateTime.utc(2026, 11, 10, 1);
      final dias = proximosDias(agora, quantidade: 3);
      expect(dias, [
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 11),
      ]);
    });

    test('vira o mês sem pular dia', () {
      final dias = proximosDias(DateTime.utc(2026, 11, 29, 15), quantidade: 3);
      expect(dias, [
        DateTime(2026, 11, 29),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 1),
      ]);
    });

    test('rótulos: Hoje, Amanhã e depois a data', () {
      final agora = DateTime.utc(2026, 11, 9, 15);
      expect(rotuloDoDia(DateTime(2026, 11, 9), agora), 'Hoje');
      expect(rotuloDoDia(DateTime(2026, 11, 10), agora), 'Amanhã');
      expect(rotuloDoDia(DateTime(2026, 11, 11), agora), 'qua., 11 de nov.');
    });
  });
}
