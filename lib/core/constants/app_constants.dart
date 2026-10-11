class AppConstants {
  static const String appName = 'STREAK';
  static const String appTagline = 'No rompas la racha';
  static const String appSlogan = 'Quinielas de fútbol donde lo que cuenta no es acertar una vez, es no fallar nunca.';

  // Reglas del Motor de Puntuación (A5 / RN-45 a RN-48)
  static const int puntosMarcadorExacto = 5;
  static const int puntosGanadorCorrecto = 3;
  static const int puntosDiferenciaGolesExtra = 1; // Total: 4
  static const int puntosFallo = 0;

  // Límites de Participantes (RN-26)
  static const int minParticipantes = 2;
  static const int maxParticipantesGratis = 50;
  static const int maxParticipantesPro = 100;

  // Tiempos Críticos (RN-37)
  static const int minutosCierrePronostico = 5;
  static const int vigenciaJwtDias = 7;
}
