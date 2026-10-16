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

  // Correo de soporte/privacidad. Se define al compilar: --dart-define=SUPPORT_EMAIL=soporte@dominio.com
  // (el valor por defecto es un marcador y el build de release lo rechaza).
  static const String correoSoporte = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '[CORREO_SOPORTE]');

  // Plan Pro (RN-61 a RN-65): el precio y la moneda se leen de GET /pro/estado/ (EstadoPro).

  // Clave publicable de Stripe (modo prueba): --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
  static const String stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  // Recuperar contraseña (pantalla 03). DECISIÓN PENDIENTE: enlace o contraseña temporal. El backend envía un
  // ENLACE de un solo uso válido 1 hora (API del backend, "Recuperacion y sesiones"), así que el texto describe el enlace.
  // Si se decide la contraseña temporal, solo hay que cambiar estas constantes.
  static const String textoRecuperarPassword =
      'Escribe el correo con el que te registraste y te enviaremos las instrucciones para recuperar tu acceso.';
  static const String textoRecuperarEnviado =
      'Si el correo está registrado, te llegará un enlace para elegir una contraseña nueva. Vence en una hora.';

  // Tiempos Críticos (RN-37)
  static const int minutosCierrePronostico = 5;
  static const int vigenciaJwtDias = 7;
}
