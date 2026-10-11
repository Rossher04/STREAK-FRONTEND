class Torneo {
  const Torneo({
    required this.id,
    required this.nombre,
    required this.formato,
    required this.temporada,
    required this.estado,
    this.empezado = false,
  });

  final int id;
  final String nombre;
  final String formato;
  final String temporada;
  final String estado;
  final bool empezado;

  bool get esActivo => estado == 'ACTIVO';
}

class Quiniela {
  const Quiniela({
    required this.id,
    required this.nombre,
    required this.torneo,
    required this.codigoUnico,
    required this.maxParticipantes,
    required this.inscritos,
    required this.puntosUsuario,
    required this.puesto,
    required this.esHistorial,
    required this.torneoEmpezado,
  });

  final int id;
  final String nombre;
  final Torneo torneo;
  final String codigoUnico;
  final int maxParticipantes;
  final int inscritos;
  final int puntosUsuario;
  final int puesto;
  final bool esHistorial;
  final bool torneoEmpezado;
}
