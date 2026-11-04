// Fixtures copiadas do contrato (docs/tarefas.md) e dos dados fixos do seed.
import 'dart:convert';

import 'package:barberhub_app/core/formatters.dart';
import 'package:barberhub_app/data/models/agendamento.dart';
import 'package:barberhub_app/data/models/barbearia.dart';
import 'package:barberhub_app/data/models/disponibilidade.dart';
import 'package:barberhub_app/data/models/profissional.dart';
import 'package:barberhub_app/data/models/servico.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String texto) =>
    jsonDecode(texto) as Map<String, dynamic>;

void main() {
  test('barbearia e profissional do seed', () {
    final barbearia = Barbearia.fromJson(
      _json(
        '{"id": "11111111-1111-1111-1111-111111111111", '
        '"nome": "Barbearia Centro", "endereco": "Rua da Bahia 1000"}',
      ),
    );
    final profissional = Profissional.fromJson(
      _json(
        '{"id": "22222222-2222-2222-2222-222222222222", '
        '"barbearia_id": "11111111-1111-1111-1111-111111111111", "nome": "Carlos"}',
      ),
    );

    expect(barbearia.endereco, 'Rua da Bahia 1000');
    expect(profissional.barbeariaId, barbearia.id);
    expect(Barbearia.fromJson(barbearia.toJson()), barbearia);
  });

  test('preço vem como texto do FastAPI ("40.00") ou como número', () {
    const base =
        '"id": "33333333-3333-3333-3333-333333333333", '
        '"barbearia_id": "11111111-1111-1111-1111-111111111111", '
        '"nome": "Corte", "duracao_min": 30';

    expect(Servico.fromJson(_json('{$base, "preco": "40.00"}')).preco, 40.0);
    expect(Servico.fromJson(_json('{$base, "preco": 40}')).preco, 40.0);
    expect(
      () => Servico.fromJson(_json('{$base, "preco": null}')),
      throwsFormatException,
    );
  });

  test('disponibilidade guarda o dia do calendário e os instantes', () {
    final disponibilidade = Disponibilidade.fromJson(
      _json('''
      {
        "profissional_id": "22222222-2222-2222-2222-222222222222",
        "data": "2026-10-28",
        "horarios_livres": [
          {"inicio": "2026-10-28T09:00:00-03:00", "fim": "2026-10-28T09:30:00-03:00"},
          {"inicio": "2026-10-28T09:30:00-03:00", "fim": "2026-10-28T10:00:00-03:00"}
        ]
      }'''),
    );

    expect(disponibilidade.data, DateTime(2026, 10, 28));
    expect(disponibilidade.horariosLivres, hasLength(2));
    final primeiro = disponibilidade.horariosLivres.first;
    expect(primeiro.inicio, DateTime.utc(2026, 10, 28, 12)); // 09:00 em -03:00
    expect(formatHora(primeiro.inicio), '09:00');
  });

  test('a reserva manda o horário de volta com -03:00, igual ao contrato', () {
    final horario = HorarioLivre.fromJson(
      _json(
        '{"inicio": "2026-10-28T10:00:00-03:00", "fim": "2026-10-28T10:30:00-03:00"}',
      ),
    );
    final corpo = NovoAgendamento(
      barbeariaId: '11111111-1111-1111-1111-111111111111',
      profissionalId: '22222222-2222-2222-2222-222222222222',
      servicoId: '33333333-3333-3333-3333-333333333333',
      horario: horario,
    ).toJson();

    expect(corpo, {
      'barbearia_id': '11111111-1111-1111-1111-111111111111',
      'profissional_id': '22222222-2222-2222-2222-222222222222',
      'servico_id': '33333333-3333-3333-3333-333333333333',
      'inicio': '2026-10-28T10:00:00-03:00',
      'fim': '2026-10-28T10:30:00-03:00',
    });
  });

  test('agendamento criado (201) com status CONFIRMADO', () {
    final agendamento = Agendamento.fromJson(
      _json('''
      {
        "id": "44444444-4444-4444-4444-444444444444",
        "barbearia_id": "11111111-1111-1111-1111-111111111111",
        "profissional_id": "22222222-2222-2222-2222-222222222222",
        "servico_id": "33333333-3333-3333-3333-333333333333",
        "cliente_id": "valor do X-User-ID",
        "inicio": "2026-10-28T10:00:00-03:00",
        "fim": "2026-10-28T10:30:00-03:00",
        "status": "CONFIRMADO"
      }'''),
    );

    expect(agendamento.status, StatusAgendamento.confirmado);
    expect(agendamento.toJson()['status'], 'CONFIRMADO');
    expect(agendamento.toJson()['inicio'], '2026-10-28T10:00:00-03:00');
  });
}
