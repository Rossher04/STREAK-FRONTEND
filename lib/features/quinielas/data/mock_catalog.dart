import '../domain/models.dart';

/// Datos locales hasta que existan GET /quinielas/mias y /historial (Día 8).
class MockCatalog {
  MockCatalog._();

  static final torneos = <Torneo>[
    const Torneo(
      id: 1,
      nombre: 'Liga STREAK Apertura',
      formato: 'LIGA',
      temporada: '2026',
      estado: 'ACTIVO',
      empezado: true,
    ),
    const Torneo(
      id: 2,
      nombre: 'Copa Grupos Demo',
      formato: 'GRUPOS_ELIMINATORIA',
      temporada: '2026',
      estado: 'ACTIVO',
      empezado: false,
    ),
    const Torneo(
      id: 3,
      nombre: 'Borrador (no debe usarse)',
      formato: 'LIGA',
      temporada: '2026',
      estado: 'BORRADOR',
    ),
  ];

  static List<Torneo> get activos =>
      torneos.where((t) => t.esActivo).toList();

  static final List<Quiniela> seed = [
    Quiniela(
      id: 1,
      nombre: 'Oficina no falla',
      torneo: activos.first,
      codigoUnico: 'K7P2XM',
      maxParticipantes: 12,
      inscritos: 8,
      puntosUsuario: 28,
      puesto: 3,
      esHistorial: false,
      torneoEmpezado: true,
    ),
    Quiniela(
      id: 2,
      nombre: 'Barrio 90 minutos',
      torneo: activos.last,
      codigoUnico: 'H4N9QR',
      maxParticipantes: 6,
      inscritos: 4,
      puntosUsuario: 0,
      puesto: 2,
      esHistorial: false,
      torneoEmpezado: false,
    ),
    const Quiniela(
      id: 3,
      nombre: 'Clausura 2025',
      torneo: Torneo(
        id: 9,
        nombre: 'Clausura cerrada',
        formato: 'LIGA',
        temporada: '2025',
        estado: 'FINALIZADO',
        empezado: true,
      ),
      codigoUnico: 'Z8M3WT',
      maxParticipantes: 10,
      inscritos: 10,
      puntosUsuario: 41,
      puesto: 1,
      esHistorial: true,
      torneoEmpezado: true,
    ),
  ];
}
