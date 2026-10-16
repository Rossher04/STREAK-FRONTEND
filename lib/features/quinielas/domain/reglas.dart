/// Reglas puras de la quiniela activa (B5), sin dependencias de Flutter ni de red.
library;

/// Minutos antes del inicio en que se cierra la edición (RN-37). Desde a86fe6d el backend publica
/// `cierre_pronosticos` (inicio − 5 min) y rechaza después con PRONOSTICOS_CERRADOS; este valor solo es
/// el respaldo cuando la respuesta no trae ese campo.
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

/// Tipos de fase que el backend normaliza (Fase.Tipo, a86fe6d).
const tiposFase = {'LIGA', 'GRUPOS', 'ELIMINATORIA'};

/// ¿La fase es eliminatoria? (RN-23: solo cuenta el tiempo reglamentario).
/// El backend ya normaliza `tipo` a LIGA, GRUPOS o ELIMINATORIA y se usa ese valor. Solo si llega un tipo
/// desconocido (datos antiguos o una copia guardada) se recurre a la heurística por palabras clave en
/// `tipo` o `nombre` (ELIM, OCTAV, CUART, SEMI, FINAL, sin distinguir mayúsculas ni tildes).
bool esFaseEliminatoria(String tipo, String nombre) {
  final t = tipo.trim().toUpperCase();
  if (tiposFase.contains(t)) return t == 'ELIMINATORIA';
  final texto = '${_normalizar(tipo)} ${_normalizar(nombre)}';
  return _marcasEliminatoria.any(texto.contains);
}

/// Instante de cierre de pronósticos: el `cierre_pronosticos` del servidor si viene (RN-37) o, si no,
/// 5 minutos antes de fecha_hora.
DateTime cierreDe(DateTime fechaHora, {DateTime? cierreServidor}) =>
    cierreServidor ?? fechaHora.subtract(const Duration(minutes: minutosCierre));

/// ¿Se puede editar el pronóstico de un partido? (RN-33, RN-37)
/// Solo PROGRAMADO, con el torneo no finalizado y antes del cierre según la hora del servidor.
/// Si el servidor ya dijo `pronosticos_abiertos: false`, sigue cerrado (el tiempo solo avanza).
bool puedeEditarPronostico({
  required String estadoPartido,
  required DateTime fechaHora,
  required DateTime ahoraServidor,
  required bool torneoFinalizado,
  DateTime? cierreServidor,
  bool? abiertoServidor,
}) {
  if (torneoFinalizado || estadoPartido != 'PROGRAMADO' || abiertoServidor == false) return false;
  return ahoraServidor.isBefore(cierreDe(fechaHora, cierreServidor: cierreServidor));
}

/// Texto del chip de cierre cuando falta poco (≤ 24 h): "Cierra en 1 h 20 min", "Cierra en 8 min",
/// "Cierra en menos de 1 min". null si falta más de un día o ya cerró (entonces se usa [textoCierre]).
String? textoCierraEn(DateTime cierre, DateTime ahoraServidor) {
  final falta = cierre.difference(ahoraServidor);
  if (falta <= Duration.zero || falta > const Duration(hours: 24)) return null;
  final h = falta.inHours;
  final m = falta.inMinutes % 60;
  if (h == 0 && m == 0) return 'Cierra en menos de 1 min';
  if (h == 0) return 'Cierra en $m min';
  return m == 0 ? 'Cierra en $h h' : 'Cierra en $h h $m min';
}

const _diasSemana = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// Cuándo cierra la edición, en hora local y diciendo el día para que no parezca que es hoy:
/// "Cierra hoy a las 17:13", "Cierra mañana a las 09:05" o "Cierra mar 13 · 17:13".
/// `cierre` y `ahora` pueden venir en UTC; el día se compara en hora local.
String textoCierre({required DateTime cierre, required DateTime ahora}) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final c = cierre.toLocal();
  final a = ahora.toLocal();
  final hora = '${dos(c.hour)}:${dos(c.minute)}';
  // Días de calendario de diferencia (en UTC para que el horario de verano no altere la cuenta).
  final dias = DateTime.utc(c.year, c.month, c.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  if (dias == 0) return 'Cierra hoy a las $hora';
  if (dias == 1) return 'Cierra mañana a las $hora';
  return 'Cierra ${_diasSemana[c.weekday - 1]} ${c.day} · $hora';
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
