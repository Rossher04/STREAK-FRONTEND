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

  // Plan Pro (RN-61 a RN-65). El backend cobra STRIPE_PRO_AMOUNT (500 centavos = USD 5.00,
  // settings.py) y no expone el precio por API, por eso se repite aquí para mostrarlo en el paywall.
  static const String precioProUsd = '5.00';

  // Clave publicable de Stripe (modo prueba): --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
  static const String stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  // Tiempos Críticos (RN-37)
  static const int minutosCierrePronostico = 5;
  static const int vigenciaJwtDias = 7;
}
