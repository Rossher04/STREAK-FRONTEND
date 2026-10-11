import 'models.dart';
import 'reglas.dart';

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
  String toString() => '$local - $visita';
}

/// Partido tal como lo devuelve el backend (PartidoSerializer). Según el endpoint trae además
/// el pronóstico propio (mi_pronostico / mis_puntos) o el de un participante (pronostico /
/// puntos_obtenidos).
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
  });

  factory Partido.fromJson(Map<String, dynamic> j) {
    final pron = j['mi_pronostico'] ?? j['pronostico'];
    return Partido(
      id: j['id'] as int,
      faseId: j['fase'] as int,
      equipoLocalId: j['equipo_local'] as int,
      equipoVisitaId: j['equipo_visita'] as int,
      fechaHora: DateTime.parse(j['fecha_hora'] as String).toUtc(),
      estado: j['estado'] as String? ?? '',
      golesLocal: j['goles_local'] as int?,
      golesVisita: j['goles_visita'] as int?,
      pronostico: pron is Map<String, dynamic> ? Marcador.fromPronostico(pron) : null,
      puntos: (j['mis_puntos'] ?? j['puntos_obtenidos'] ?? 0) as int,
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
  final int puntos;

  bool get esResuelto => estado == 'FINALIZADO' || estado == 'SUSPENDIDO' || estado == 'CANCELADO';
  Marcador? get resultado =>
      (golesLocal != null && golesVisita != null) ? Marcador(golesLocal!, golesVisita!) : null;

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
      );
}

/// Fila de GET /quinielas/{id}/tabla/. El backend no envía foto ni es_pro por participante.
class FilaTabla {
  const FilaTabla({
    required this.participanteId,
    required this.usuarioId,
    required this.username,
    required this.puntos,
    required this.posicion,
  });

  factory FilaTabla.fromJson(Map<String, dynamic> j) => FilaTabla(
        participanteId: j['id'] as int,
        usuarioId: j['usuario'] as int,
        username: j['username'] as String? ?? '',
        puntos: j['puntos_totales'] as int? ?? 0,
        posicion: j['posicion'] as int? ?? 0,
      );

  final int participanteId;
  final int usuarioId;
  final String username;
  final int puntos;
  final int posicion;
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
    this.offlineDesde,
  });

  /// Respuestas crudas de la API: `quiniela`, `torneo`, `equipos`, `fases`, `partidos`, `tabla`.
  factory QuinielaVista.fromRaw(Map<String, dynamic> raw, {DateTime? offlineDesde}) {
    List<Map<String, dynamic>> lista(String k) => (raw[k] as List).cast<Map<String, dynamic>>();
    return QuinielaVista(
      quiniela: Quiniela.fromJson(raw['quiniela'] as Map<String, dynamic>),
      torneo: Torneo.fromJson(raw['torneo'] as Map<String, dynamic>),
      equipos: {for (final e in lista('equipos').map(Equipo.fromJson)) e.id: e},
      fases: {for (final f in lista('fases').map(Fase.fromJson)) f.id: f},
      partidos: lista('partidos').map(Partido.fromJson).toList(),
      tabla: lista('tabla').map(FilaTabla.fromJson).toList(),
      offlineDesde: offlineDesde,
    );
  }

  final Quiniela quiniela;
  final Torneo torneo;
  final Map<int, Equipo> equipos;
  final Map<int, Fase> fases;
  final List<Partido> partidos;
  final List<FilaTabla> tabla;
  final DateTime? offlineDesde;

  bool get offline => offlineDesde != null;
  bool get torneoFinalizado => torneo.esFinalizado;

  String nombreEquipo(int id) => equipos[id]?.nombre ?? 'Equipo';

  FilaTabla? filaDe(int usuarioId) {
    for (final f in tabla) {
      if (f.usuarioId == usuarioId) return f;
    }
    return null;
  }

  /// Pendientes: aún no resueltos (PROGRAMADO y EN_JUEGO), por fecha.
  List<Partido> get pendientes =>
      (partidos.where((p) => !p.esResuelto).toList()..sort((a, b) => a.fechaHora.compareTo(b.fechaHora)));

  /// Finalizados: resueltos (FINALIZADO, SUSPENDIDO, CANCELADO), los más recientes primero.
  List<Partido> get resueltos =>
      (partidos.where((p) => p.esResuelto).toList()..sort((a, b) => b.fechaHora.compareTo(a.fechaHora)));

  QuinielaVista conPartidos(List<Partido> nuevos) => QuinielaVista(
        quiniela: quiniela,
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
  });

  final int usuarioId;
  final String username;
  final Marcador? pronostico; // null: oculto hasta el inicio, o sin pronóstico
  final int puntos;
}

class PartidoDetalle {
  const PartidoDetalle({required this.partido, required this.participantes});

  factory PartidoDetalle.fromJson(Map<String, dynamic> j) {
    final lista = (j['participantes'] as List).cast<Map<String, dynamic>>();
    return PartidoDetalle(
      partido: Partido.fromJson(j['partido'] as Map<String, dynamic>),
      participantes: [
        for (final p in lista)
          ParticipanteEnPartido(
            usuarioId: p['usuario'] as int,
            username: p['username'] as String? ?? '',
            pronostico: p['pronostico'] is Map<String, dynamic>
                ? Marcador.fromPronostico(p['pronostico'] as Map<String, dynamic>)
                : null,
            puntos: p['puntos_obtenidos'] as int? ?? 0,
          ),
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
  });

  factory ParticipanteDetalle.fromJson(Map<String, dynamic> j) {
    final p = j['participante'] as Map<String, dynamic>;
    return ParticipanteDetalle(
      usuarioId: p['usuario'] as int,
      username: p['username'] as String? ?? '',
      puntosTotales: p['puntos_totales'] as int? ?? 0,
      partidos: (j['partidos'] as List).cast<Map<String, dynamic>>().map(Partido.fromJson).toList(),
    );
  }

  final int usuarioId;
  final String username;
  final int puntosTotales;
  final List<Partido> partidos;
}
