/// Lista devuelta por la API o, sin conexión (RN-74), la última copia guardada.
/// `offlineDesde` != null indica que son datos guardados en ese instante (UTC).
class Listado<T> {
  const Listado({required this.items, this.offlineDesde});

  final List<T> items;
  final DateTime? offlineDesde;

  bool get offline => offlineDesde != null;
}

class Torneo {
  const Torneo({
    required this.id,
    required this.nombre,
    required this.formato,
    required this.temporada,
    required this.estado,
  });

  factory Torneo.fromJson(Map<String, dynamic> json) => Torneo(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        formato: json['formato'] as String? ?? '',
        temporada: json['temporada'] as String? ?? '',
        estado: json['estado'] as String? ?? '',
      );

  final int id;
  final String nombre;
  final String formato;
  final String temporada;
  final String estado;

  bool get esActivo => estado == 'ACTIVO';
  bool get esFinalizado => estado == 'FINALIZADO';
}

/// Quiniela tal como la devuelve el backend (QuinielaSerializer). En `/mias/`, `/historial/` y el detalle trae
/// además el resumen del usuario: `torneo_nombre`, `cantidad_inscritos`, `mis_puntos` y `mi_posicion`
/// (backend 91ebd2a). `creador` es null si quien la creó eliminó su cuenta.
class Quiniela {
  const Quiniela({
    required this.id,
    required this.nombre,
    required this.torneoId,
    this.creadorId,
    required this.codigoUnico,
    required this.maxParticipantes,
    this.torneoNombre,
    this.cantidadInscritos,
    this.misPuntos,
    this.miPosicion,
  });

  factory Quiniela.fromJson(Map<String, dynamic> json) => Quiniela(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        torneoId: json['torneo'] as int,
        creadorId: json['creador'] as int?,
        codigoUnico: json['codigo_unico'] as String? ?? '',
        maxParticipantes: json['max_participantes'] as int? ?? 0,
        torneoNombre: json['torneo_nombre'] as String?,
        cantidadInscritos: json['cantidad_inscritos'] as int?,
        misPuntos: json['mis_puntos'] as int?,
        miPosicion: json['mi_posicion'] as int?,
      );

  final int id;
  final String nombre;
  final int torneoId;
  final int? creadorId;
  final String codigoUnico;
  final int maxParticipantes;
  final String? torneoNombre;
  final int? cantidadInscritos;
  final int? misPuntos;

  /// Puesto con empates compartidos (1 + participantes con más puntos).
  final int? miPosicion;
}
