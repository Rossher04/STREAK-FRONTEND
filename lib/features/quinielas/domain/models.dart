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

/// Respuesta de POST /quinielas/validar-codigo/: vista previa de la quiniela antes de unirse
/// (no inscribe). Si `requiereConfirmacion`, hay que avisar del ingreso tardío (RN-31) y enviar
/// `aceptar_ingreso_tardio: true` a /quinielas/unirse/.
class ValidacionCodigo {
  const ValidacionCodigo({
    required this.quinielaId,
    required this.nombre,
    required this.torneoNombre,
    required this.cantidadInscritos,
    required this.maxParticipantes,
    required this.ingresoTardio,
    required this.requiereConfirmacion,
    required this.partidosCerrados,
    required this.penalizacionPuntos,
    required this.advertencia,
  });

  factory ValidacionCodigo.fromJson(Map<String, dynamic> json) => ValidacionCodigo(
        quinielaId: json['quiniela_id'] as int,
        nombre: json['nombre'] as String? ?? '',
        torneoNombre: json['torneo_nombre'] as String? ?? '',
        cantidadInscritos: json['cantidad_inscritos'] as int? ?? 0,
        maxParticipantes: json['max_participantes'] as int? ?? 0,
        ingresoTardio: json['ingreso_tardio'] as bool? ?? false,
        requiereConfirmacion: json['requiere_confirmacion'] as bool? ?? false,
        partidosCerrados: json['partidos_cerrados'] as int? ?? 0,
        penalizacionPuntos: json['penalizacion_puntos'] as int? ?? 0,
        advertencia: json['advertencia'] as String? ?? '',
      );

  final int quinielaId;
  final String nombre;
  final String torneoNombre;
  final int cantidadInscritos;
  final int maxParticipantes;
  final bool ingresoTardio;
  final bool requiereConfirmacion;
  final int partidosCerrados;

  /// Siempre 0 en el backend actual: no se descuentan puntos por entrar tarde.
  final int penalizacionPuntos;
  final String advertencia;
}
