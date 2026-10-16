/// Estado que se muestra en cada tarjeta del Inicio (07): "En juego" o "Cierra en …".
library;

/// Partido mínimo para decidir el chip: estado y `cierre_pronosticos` del servidor (inicio − 5 min, RN-37).
class PartidoResumen {
  const PartidoResumen({required this.estado, required this.cierre, required this.conPronostico});

  factory PartidoResumen.fromJson(Map<String, dynamic> j) => PartidoResumen(
        estado: j['estado'] as String? ?? '',
        // El backend publica cierre_pronosticos; si faltara, se calcula igual que el servidor.
        cierre: j['cierre_pronosticos'] != null
            ? DateTime.parse(j['cierre_pronosticos'] as String).toUtc()
            : DateTime.parse(j['fecha_hora'] as String).toUtc().subtract(const Duration(minutes: 5)),
        conPronostico: j['mi_pronostico'] != null,
      );

  final String estado;
  final DateTime cierre;
  final bool conPronostico;
}

enum TipoChipInicio { ninguno, enJuego, cierraPronto }

/// Lo que dice el chip de una quiniela del Inicio.
class ChipInicio {
  const ChipInicio(this.tipo, [this.texto = '']);

  final TipoChipInicio tipo;
  final String texto;

  static const ninguno = ChipInicio(TipoChipInicio.ninguno);
}

/// Ventana en la que se avisa "Cierra en …".
const ventanaCierre = Duration(hours: 24);

/// "Cierra en 2 h" / "Cierra en 45 min" / "Cierra en 1 h 20 min".
String textoCierraEn(Duration falta) {
  final h = falta.inHours;
  final m = falta.inMinutes % 60;
  if (h == 0) return 'Cierra en ${m < 1 ? 1 : m} min';
  return m == 0 ? 'Cierra en $h h' : 'Cierra en $h h $m min';
}

/// Prioridad: un partido que cierra en menos de 24 h y aún no tiene tu pronóstico ("Cierra en …", alerta) y, si no,
/// "En juego" mientras el torneo esté activo. Torneo finalizado o desconocido: sin chip.
ChipInicio chipInicio({
  required bool torneoActivo,
  required List<PartidoResumen> partidos,
  required DateTime ahoraServidor,
}) {
  if (!torneoActivo) return ChipInicio.ninguno;
  final porCerrar = partidos
      .where((p) =>
          p.estado == 'PROGRAMADO' &&
          !p.conPronostico &&
          p.cierre.isAfter(ahoraServidor) &&
          p.cierre.difference(ahoraServidor) <= ventanaCierre)
      .map((p) => p.cierre)
      .toList()
    ..sort();
  if (porCerrar.isNotEmpty) {
    return ChipInicio(TipoChipInicio.cierraPronto, textoCierraEn(porCerrar.first.difference(ahoraServidor)));
  }
  return const ChipInicio(TipoChipInicio.enJuego, 'En juego');
}
