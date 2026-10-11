/// Reglas puras de la quiniela activa (B5), sin dependencias de Flutter ni de red.
library;

/// Minutos antes del inicio en que la app cierra la edición (RN-37).
/// El backend cierra recién al llegar fecha_hora (views_api.py: PRONOSTICOS_CERRADOS).
const minutosCierre = 5;

/// Rango del editor de marcador (RN-35).
const golesMin = 0;
const golesMax = 20;

/// Puesto en la tabla: "1.º" o "3.º de 12" si se conoce el total (RN-53).
/// `posicion` viene del backend con empates compartidos (1, 1, 3).
String etiquetaPuesto(int posicion, [int? total]) {
  final base = '$posicion.º';
  return total == null ? base : '$base de $total';
}

/// Etiqueta de puntos de un partido ya resuelto (RN-22, RN-45 a RN-48).
String etiquetaPuntos({
  required String estado,
  required bool tienePronostico,
  required int puntos,
}) {
  if (estado == 'SUSPENDIDO' || estado == 'CANCELADO') return '0 pts · no cuenta';
  if (!tienePronostico) return 'Sin pronóstico · 0 pts';
  switch (puntos) {
    case 5:
      return 'Exacto · 5 pts';
    case 4:
      return 'Diferencia · 4 pts';
    case 3:
      return 'Resultado · 3 pts';
    default:
      return 'Fallo · 0 pts';
  }
}

String _normalizar(String s) => s
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U');

const _marcasEliminatoria = ['ELIM', 'OCTAV', 'CUART', 'SEMI', 'FINAL'];

/// Heurística: Fase.tipo es texto libre (models.py), así que se considera fase de
/// eliminación si `tipo` o `nombre` contienen ELIM, OCTAV, CUART, SEMI o FINAL
/// (sin distinguir mayúsculas ni tildes). Una fase de liga llamada "Ronda final"
/// daría un falso positivo; el backend debería exponer un tipo cerrado.
bool esFaseEliminatoria(String tipo, String nombre) {
  final texto = '${_normalizar(tipo)} ${_normalizar(nombre)}';
  return _marcasEliminatoria.any(texto.contains);
}

/// Instante de cierre de pronósticos en la app: 5 minutos antes de fecha_hora.
DateTime cierreDe(DateTime fechaHora) =>
    fechaHora.subtract(const Duration(minutes: minutosCierre));

/// ¿Se puede editar el pronóstico de un partido? (RN-33, RN-37)
/// Solo PROGRAMADO, con el torneo no finalizado y antes del cierre (hora del servidor).
bool puedeEditarPronostico({
  required String estadoPartido,
  required DateTime fechaHora,
  required DateTime ahoraServidor,
  required bool torneoFinalizado,
}) {
  if (torneoFinalizado || estadoPartido != 'PROGRAMADO') return false;
  return ahoraServidor.isBefore(cierreDe(fechaHora));
}

/// Cuenta regresiva "mm:ss" (o "h:mm:ss") hasta el cierre, solo en la última hora;
/// null si falta más de una hora o ya cerró.
String? cuentaRegresiva(DateTime fechaHora, DateTime ahoraServidor) {
  final falta = cierreDe(fechaHora).difference(ahoraServidor);
  if (falta <= Duration.zero || falta > const Duration(hours: 1)) return null;
  String dos(int n) => n.toString().padLeft(2, '0');
  final h = falta.inHours;
  final m = falta.inMinutes % 60;
  final s = falta.inSeconds % 60;
  return h > 0 ? '$h:${dos(m)}:${dos(s)}' : '${dos(m)}:${dos(s)}';
}
