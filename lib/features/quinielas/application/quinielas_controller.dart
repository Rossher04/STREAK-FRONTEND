import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_catalog.dart';
import '../domain/models.dart';

final quinielasControllerProvider =
    NotifierProvider<QuinielasController, List<Quiniela>>(QuinielasController.new);

class QuinielasController extends Notifier<List<Quiniela>> {
  @override
  List<Quiniela> build() => List<Quiniela>.from(MockCatalog.seed);

  List<Quiniela> get activas =>
      state.where((q) => !q.esHistorial).toList();

  List<Quiniela> get historial =>
      state.where((q) => q.esHistorial).toList();

  Quiniela crear({
    required String nombre,
    required Torneo torneo,
    required int maxParticipantes,
  }) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final codigo = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    final q = Quiniela(
      id: state.length + 10,
      nombre: nombre,
      torneo: torneo,
      codigoUnico: codigo,
      maxParticipantes: maxParticipantes,
      inscritos: 1,
      puntosUsuario: 0,
      puesto: 1,
      esHistorial: false,
      torneoEmpezado: torneo.empezado,
    );
    state = [q, ...state];
    return q;
  }

  Quiniela unirse(String codigo) {
    final code = codigo.trim().toUpperCase();
    final existente = state.where((q) => q.codigoUnico == code).toList();
    if (existente.isNotEmpty) {
      return existente.first;
    }
    final torneo = MockCatalog.activos.first;
    final q = Quiniela(
      id: state.length + 20,
      nombre: 'Quiniela $code',
      torneo: torneo,
      codigoUnico: code,
      maxParticipantes: 12,
      inscritos: 5,
      puntosUsuario: 0,
      puesto: 5,
      esHistorial: false,
      torneoEmpezado: torneo.empezado,
    );
    state = [q, ...state];
    return q;
  }
}
