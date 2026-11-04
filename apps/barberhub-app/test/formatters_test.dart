import 'package:barberhub_app/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hora sai no fuso da barbearia, qualquer que seja o fuso do aparelho',
    () {
      // 13:00 UTC = 10:00 em -03:00, também num emulador configurado em UTC
      final instante = DateTime.utc(2026, 11, 9, 13);
      expect(formatHora(instante), '10:00');
      expect(formatHora(instante.toLocal()), '10:00');
      expect(formatInstanteApi(instante), '2026-11-09T10:00:00-03:00');
    },
  );

  test('instante perto da meia-noite UTC fica no dia certo da barbearia', () {
    // 01:30 UTC de 10/11 = 22:30 de 09/11 em -03:00
    final instante = DateTime.utc(2026, 11, 10, 1, 30);
    expect(formatDia(naBarbearia(instante)), 'seg., 9 de nov.');
    expect(formatInstanteApi(instante), '2026-11-09T22:30:00-03:00');
  });

  test('dia, data da API, preço e duração em português', () {
    expect(formatDia(DateTime(2026, 11, 14)), 'sáb., 14 de nov.');
    expect(formatDataApi(DateTime(2026, 1, 5)), '2026-01-05');
    expect(formatPreco(40), r'R$ 40,00');
    expect(formatPreco(1250.5), r'R$ 1.250,50');
    expect(formatPreco(0.1 + 0.2), r'R$ 0,30');
    expect(formatDuracao(30), '30 min');
    expect(formatDuracao(60), '1 h');
    expect(formatDuracao(75), '1 h 15 min');
  });
}
