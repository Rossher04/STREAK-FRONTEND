import 'models.dart';
import 'reglas.dart';
import 'resumen_quiniela.dart';

export 'resumen_quiniela.dart';

class Equipo {
  const Equipo({required this.id, required this.nombre, this.escudo});

  factory Equipo.fromJson(Map<String, dynamic> j) =>
      Equipo(id: j['id'] as int, nombre: j['nombre'] as String? ?? '', escudo: j['escudo'] as String?);

  final int id;
  final String nombre;
  final String? escudo;
}

class Fase {
  const Fase({required this.id, required this.nombre, required this.orden, required this.tipo});

  factory Fase.fromJson(Map<String, dynamic> j) => Fase(
        id: j['id'] as int,
        nombre: j['nombre'] as String? ?? '',
        orden: j['orden'] as int? ?? 0,
        tipo: j['tipo'] as String? ?? '',
      );

  final int id;
  final String nombre;
  final int orden;
  final String tipo;

  /// Usa el tipo normalizado del backend (LIGA / GRUPOS / ELIMINATORIA); heurística solo de respaldo.
  bool get esEliminatoria => esFaseEliminatoria(tipo, nombre);
}

class Marcador {
  const Marcador(this.local, this.visita);

  /// Desde un Pronostico del backend (goles_local_pred / goles_visita_pred).
  factory Marcador.fromPronostico(Map<String, dynamic> j) =>
      Marcador(j['goles_local_pred'] as int, j['goles_visita_pred'] as int);

  final int local;
  final int visita;

  @override
  bool operator ==(Object other) => other is Marcador && other.local == local && other.visita == visita;

  @override
  int get hashCode => Object.hash(local, visita);

  @override
  String toString() => '$local – $visita';
}

/// Visibilidad del pronóstico de un participante (campo `estado_pronostico` del backend, RN-39).
enum EstadoPronostico {
  /// Se ve el marcador.
  visible,

  /// El participante no pronosticó (o el partido ya empezó sin pronóstico).
  noRegistrado,

  /// Pronóstico ajeno antes del inicio: el backend no revela si existe.
  oculto;

  /// Lee `estado_pronostico`. Si falta (respuesta antigua o copia guardada) se decide solo por si hay
  /// marcador: nunca se deduce "oculto" por la hora del teléfono.
  static EstadoPronostico desde(Object? valor, {required bool hayMarcador}) => switch (valor) {
        'OCULTO' => EstadoPronostico.oculto,
        'NO_REGISTRADO' => EstadoPronostico.noRegistrado,
        'VISIBLE' => EstadoPronostico.visible,
        _ => hayMarcador ? EstadoPronostico.visible : EstadoPronostico.noRegistrado,
      };
}

DateTime? _fecha(Object? v) => v is String ? DateTime.parse(v).toUtc() : null;

Equipo? _equipo(Object? v) => v is Map<String, dynamic> ? Equipo.fromJson(v) : null;

/// Partido tal como lo devuelve el backend (PartidoSerializer). Según el endpoint trae además
/// el pronóstico propio (mi_pronostico / mis_puntos) o el de un participante (pronostico /
/// puntos_obtenidos), y su `estado_pronostico`.
class Partido {
  const Partido({
    required this.id,
    required this.faseId,
    required this.equipoLocalId,
    required this.equipoVisitaId,
    required this.fechaHora,
    required this.estado,
    this.golesLocal,
    this.golesVisita,
    this.pronostico,
    this.puntos = 0,
    this.faseTipo,
    this.cierrePronosticos,
    this.pronosticosAbiertos,
    this.estadoPronostico = EstadoPronostico.noRegistrado,
    this.equipoLocal,
    this.equipoVisita,
  });

  factory Partido.fromJson(Map<String, dynamic> j) {
    final pron = j['mi_pronostico'] ?? j['pronostico'];
    final marcador = pron is Map<String, dynamic> ? Marcador.fromPronostico(pron) : null;
    return Partido(
      id: j['id'] as int,
      faseId: j['fase'] as int,
      equipoLocalId: j['equipo_local'] as int,
      equipoVisitaId: j['equipo_visita'] as int,
      fechaHora: DateTime.parse(j['fecha_hora'] as String).toUtc(),
      estado: j['estado'] as String? ?? '',
      golesLocal: j['goles_local'] as int?,
      golesVisita: j['goles_visita'] as int?,
      pronostico: marcador,
      puntos: (j['mis_puntos'] ?? j['puntos_obtenidos'] ?? 0) as int,
      faseTipo: j['fase_tipo'] as String?,
      cierrePronosticos: _fecha(j['cierre_pronosticos']),
      pronosticosAbiertos: j['pronosticos_abiertos'] as bool?,
      estadoPronostico: EstadoPronostico.desde(j['estado_pronostico'], hayMarcador: marcador != null),
      equipoLocal: _equipo(j['equipo_local_detalle']),
      equipoVisita: _equipo(j['equipo_visita_detalle']),
    );
  }

  final int id;
  final int faseId;
  final int equipoLocalId;
  final int equipoVisitaId;
  final DateTime fechaHora; // UTC (RN-70: se muestra en hora local)
  final String estado;
  final int? golesLocal;
  final int? golesVisita;
  final Marcador? pronostico;

  /// Puntos del backend (mis_puntos / puntos_obtenidos). La app nunca los recalcula.
  final int puntos;

  /// LIGA, GRUPOS o ELIMINATORIA (normalizado por el backend).
  final String? faseTipo;

  /// Inicio − 5 min según el servidor (RN-37).
  final DateTime? cierrePronosticos;
  final bool? pronosticosAbiertos;
  final EstadoPronostico estadoPronostico;
  final Equipo? equipoLocal;
  final Equipo? equipoVisita;

  bool get esResuelto => estado == 'FINALIZADO' || estado == 'SUSPENDIDO' || estado == 'CANCELADO';
  bool get noCuenta => estado == 'SUSPENDIDO' || estado == 'CANCELADO';
  bool get enJuego => estado == 'EN_JUEGO';
  Marcador? get resultado =>
      (golesLocal != null && golesVisita != null) ? Marcador(golesLocal!, golesVisita!) : null;

  DateTime get cierre => cierreDe(fechaHora, cierreServidor: cierrePronosticos);

  Partido conPronostico(Marcador m) => Partido(
        id: id,
        faseId: faseId,
        equipoLocalId: equipoLocalId,
        equipoVisitaId: equipoVisitaId,
        fechaHora: fechaHora,
        estado: estado,
        golesLocal: golesLocal,
        golesVisita: golesVisita,
        pronostico: m,
        puntos: puntos,
        faseTipo: faseTipo,
        cierrePronosticos: cierrePronosticos,
        pronosticosAbiertos: pronosticosAbiertos,
        estadoPronostico: EstadoPronostico.visible,
        equipoLocal: equipoLocal,
        equipoVisita: equipoVisita,
      );
}

/// Fila de GET /quinielas/{id}/tabla/: posición con empates compartidos (1, 1, 3) calculada por el
/// backend, foto y es_pro (RN-53/61). Solo username y foto: nunca correo ni teléfono (RN-10).
class FilaTabla {
  const FilaTabla({
    required this.participanteId,
    required this.usuarioId,
    required this.username,
    required this.puntos,
    required this.posicion,
    this.foto,
    this.esPro = false,
  });

  factory FilaTabla.fromJson(Map<String, dynamic> j) => FilaTabla(
        participanteId: j['id'] as int,
        usuarioId: j['usuario'] as int,
        username: j['username'] as String? ?? '',
        puntos: j['puntos_totales'] as int? ?? 0,
        posicion: j['posicion'] as int? ?? 0,
        foto: j['foto'] as String?,
        esPro: j['es_pro'] as bool? ?? false,
      );

  final int participanteId;
  final int usuarioId;
  final String username;
  final int puntos;
  final int posicion;
  final String? foto;
  final bool esPro;
}

/// Todo lo necesario para pintar la quiniela activa. `offlineDesde` != null indica que son
/// datos guardados (RN-74), tomados de ese instante.
class QuinielaVista {
  const QuinielaVista({
    required this.quiniela,
    required this.torneo,
    required this.equipos,
    required this.fases,
    required this.partidos,
    required this.tabla,
    this.resumen,
    this.offlineDesde,
  });

  /// Respuestas crudas de la API: `quiniela`, `torneo`, `equipos`, `fases`, `partidos`, `tabla`.
  factory QuinielaVista.fromRaw(Map<String, dynamic> raw, {DateTime? offlineDesde}) {
    List<Map<String, dynamic>> lista(String k) => (raw[k] as List).cast<Map<String, dynamic>>();
    final q = raw['quiniela'] as Map<String, dynamic>;
    return QuinielaVista(
      quiniela: Quiniela.fromJson(q),
      resumen: ResumenQuiniela.fromJson(q),
      torneo: Torneo.fromJson(raw['torneo'] as Map<String, dynamic>),
      equipos: {for (final e in lista('equipos').map(Equipo.fromJson)) e.id: e},
      fases: {for (final f in lista('fases').map(Fase.fromJson)) f.id: f},
      partidos: lista('partidos').map(Partido.fromJson).toList(),
      tabla: lista('tabla').map(FilaTabla.fromJson).toList(),
      offlineDesde: offlineDesde,
    );
  }

  final Quiniela quiniela;
  final ResumenQuiniela? resumen;
  final Torneo torneo;
  final Map<int, Equipo> equipos;
  final Map<int, Fase> fases;
  final List<Partido> partidos;
  final List<FilaTabla> tabla;
  final DateTime? offlineDesde;

  bool get offline => offlineDesde != null;
  bool get torneoFinalizado => torneo.esFinalizado;

  /// ¿Hay algún partido en juego? (chip "En juego" de la cabecera).
  bool get hayEnJuego => partidos.any((p) => p.enJuego);

  String nombreEquipo(int id) => equipos[id]?.nombre ?? 'Equipo';
  String? escudoEquipo(int id) => equipos[id]?.escudo;

  FilaTabla? filaDe(int usuarioId) {
    for (final f in tabla) {
      if (f.usuarioId == usuarioId) return f;
    }
    return null;
  }

  /// Nombre del torneo: el resumen del backend o, si falta, el detalle del torneo.
  String get torneoNombre => resumen?.torneoNombre ?? torneo.nombre;

  /// Inscritos: el resumen del backend o el tamaño de la tabla.
  int get inscritos => resumen?.cantidadInscritos ?? tabla.length;

  /// Mi puesto: `mi_posicion` del backend o, si falta, mi fila de `/tabla/`.
  int? miPuesto(int? usuarioId) =>
      resumen?.miPosicion ?? (usuarioId == null ? null : filaDe(usuarioId)?.posicion);

  /// Mis puntos: `mis_puntos` del backend o, si falta, mi fila de `/tabla/`.
  int? misPuntos(int? usuarioId) =>
      resumen?.misPuntos ?? (usuarioId == null ? null : filaDe(usuarioId)?.puntos);

  bool esEliminatoria(Partido p) {
    final fase = fases[p.faseId];
    return esFaseEliminatoria(p.faseTipo ?? fase?.tipo ?? '', fase?.nombre ?? '');
  }

  /// Pendientes: aún no resueltos (PROGRAMADO y EN_JUEGO), por fecha.
  List<Partido> get pendientes =>
      (partidos.where((p) => !p.esResuelto).toList()..sort((a, b) => a.fechaHora.compareTo(b.fechaHora)));

  /// Resultados: resueltos (FINALIZADO, SUSPENDIDO, CANCELADO), los más recientes primero.
  List<Partido> get resueltos =>
      (partidos.where((p) => p.esResuelto).toList()..sort((a, b) => b.fechaHora.compareTo(a.fechaHora)));

  QuinielaVista conPartidos(List<Partido> nuevos) => QuinielaVista(
        quiniela: quiniela,
        resumen: resumen,
        torneo: torneo,
        equipos: equipos,
        fases: fases,
        partidos: nuevos,
        tabla: tabla,
        offlineDesde: offlineDesde,
      );
}

/// Un participante dentro del detalle de un partido (GET .../partidos/{pid}/detalle/).
class ParticipanteEnPartido {
  const ParticipanteEnPartido({
    required this.usuarioId,
    required this.username,
    required this.pronostico,
    required this.puntos,
    this.estado = EstadoPronostico.noRegistrado,
    this.foto,
    this.esPro = false,
  });

  final int usuarioId;
  final String username;
  final Marcador? pronostico;
  final int puntos;
  final EstadoPronostico estado;
  final String? foto;
  final bool esPro;
}

class PartidoDetalle {
  const PartidoDetalle({required this.partido, required this.participantes});

  factory PartidoDetalle.fromJson(Map<String, dynamic> j) {
    final lista = (j['participantes'] as List).cast<Map<String, dynamic>>();
    return PartidoDetalle(
      partido: Partido.fromJson(j['partido'] as Map<String, dynamic>),
      participantes: [
        for (final p in lista)
          () {
            final m = p['pronostico'] is Map<String, dynamic>
                ? Marcador.fromPronostico(p['pronostico'] as Map<String, dynamic>)
                : null;
            return ParticipanteEnPartido(
              usuarioId: p['usuario'] as int,
              username: p['username'] as String? ?? '',
              pronostico: m,
              puntos: p['puntos_obtenidos'] as int? ?? 0,
              estado: EstadoPronostico.desde(p['estado_pronostico'], hayMarcador: m != null),
              foto: p['foto'] as String?,
              esPro: p['es_pro'] as bool? ?? false,
            );
          }(),
      ],
    );
  }

  final Partido partido;
  final List<ParticipanteEnPartido> participantes;
}

/// GET .../participantes/{uid}/detalle/ (uid = id de USUARIO).
class ParticipanteDetalle {
  const ParticipanteDetalle({
    required this.usuarioId,
    required this.username,
    required this.puntosTotales,
    required this.partidos,
    this.foto,
    this.esPro = false,
  });

  factory ParticipanteDetalle.fromJson(Map<String, dynamic> j) {
    final p = j['participante'] as Map<String, dynamic>;
    return ParticipanteDetalle(
      usuarioId: p['usuario'] as int,
      username: p['username'] as String? ?? '',
      puntosTotales: p['puntos_totales'] as int? ?? 0,
      foto: p['foto'] as String?,
      esPro: p['es_pro'] as bool? ?? false,
      partidos: (j['partidos'] as List).cast<Map<String, dynamic>>().map(Partido.fromJson).toList(),
    );
  }

  final int usuarioId;
  final String username;
  final int puntosTotales;
  final String? foto;
  final bool esPro;
  final List<Partido> partidos;
}
