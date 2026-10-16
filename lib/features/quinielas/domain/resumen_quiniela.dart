/// Resumen de una quiniela tal como lo envían `GET /quinielas/{id}/`, `/quinielas/mias/` y
/// `/quinielas/historial/` (QuinielaSerializer, backend a86fe6d): nombre del torneo, inscritos,
/// mis puntos y mi puesto. Los campos de resumen son opcionales: una respuesta antigua (o una copia
/// guardada antes del cambio) no los trae y la app recurre a `/tabla/`.
class ResumenQuiniela {
  const ResumenQuiniela({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.torneoId,
    this.torneoNombre,
    this.cantidadInscritos,
    this.misPuntos,
    this.miPosicion,
  });

  factory ResumenQuiniela.fromJson(Map<String, dynamic> j) => ResumenQuiniela(
        id: j['id'] as int,
        nombre: j['nombre'] as String? ?? '',
        codigo: j['codigo_unico'] as String? ?? '',
        torneoId: j['torneo'] as int? ?? 0,
        torneoNombre: j['torneo_nombre'] as String?,
        cantidadInscritos: j['cantidad_inscritos'] as int?,
        misPuntos: j['mis_puntos'] as int?,
        miPosicion: j['mi_posicion'] as int?,
      );

  final int id;
  final String nombre;
  final String codigo;
  final int torneoId;
  final String? torneoNombre;
  final int? cantidadInscritos;
  final int? misPuntos;

  /// Puesto con empates compartidos (1, 1, 3), calculado por el backend.
  final int? miPosicion;
}
