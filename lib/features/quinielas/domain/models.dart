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

/// Quiniela tal como la devuelve el backend (QuinielaSerializer).
/// Inscritos, puntos y puesto no vienen aquí: están en /quinielas/{id}/tabla/ (B5).
class Quiniela {
  const Quiniela({
    required this.id,
    required this.nombre,
    required this.torneoId,
    required this.creadorId,
    required this.codigoUnico,
    required this.maxParticipantes,
  });

  factory Quiniela.fromJson(Map<String, dynamic> json) => Quiniela(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        torneoId: json['torneo'] as int,
        creadorId: json['creador'] as int,
        codigoUnico: json['codigo_unico'] as String? ?? '',
        maxParticipantes: json['max_participantes'] as int? ?? 0,
      );

  final int id;
  final String nombre;
  final int torneoId;
  final int creadorId;
  final String codigoUnico;
  final int maxParticipantes;
}
