import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Utilidades de fecha y hora según RN-70 y RN-37
class DateFormatter {
  /// Convierte string UTC de la API a DateTime en hora local del dispositivo (RN-70)
  static DateTime parseUtc(String isoDate) {
    return DateTime.parse(isoDate).toLocal();
  }

  /// Formatea la fecha para la tarjeta de partido: "Sáb 15 Oct • 07:00 PM"
  static String formatMatch(DateTime localDate) {
    final DateFormat formatter = DateFormat('EEE d MMM • hh:mm a', 'es');
    return formatter.format(localDate);
  }

  /// Formatea fecha simple: "15 de octubre de 2026"
  static String formatFull(DateTime localDate) {
    final DateFormat formatter = DateFormat('d MMMM yyyy', 'es');
    return formatter.format(localDate);
  }

  /// Verifica si un partido ya cerró para pronósticos (5 minutos antes, RN-37)
  static bool isClosed(DateTime matchDate) {
    final cierre = matchDate.subtract(const Duration(minutes: AppConstants.minutosCierrePronostico));
    return DateTime.now().isAfter(cierre);
  }

  /// Retorna tiempo restante hasta el cierre
  static String timeRemaining(DateTime matchDate) {
    final cierre = matchDate.subtract(const Duration(minutes: AppConstants.minutosCierrePronostico));
    final diff = cierre.difference(DateTime.now());

    if (diff.isNegative) return 'Cerrado';
    if (diff.inDays > 0) return 'Cierra en ${diff.inDays}d';
    if (diff.inHours > 0) return 'Cierra en ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'Cierra en ${diff.inMinutes}m';
  }
}
