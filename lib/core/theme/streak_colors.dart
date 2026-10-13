import 'package:flutter/painting.dart';

/// Colores de STREAK. Fuente de verdad: `design/tokens.json` (test/tema_test.dart comprueba que coinciden).
///
/// Es el ÚNICO sitio de la app con valores de color: fuera de `lib/core/theme/` no hay `Color(0x…)`.
/// Reglas de uso (design/PALETA.md):
/// - [accent] (amarillo): una sola acción principal por pantalla, ítem activo, puntos, chip PRO.
/// - [orange]: alertas, errores, "En juego", "Cierra en…", acción destructiva y estelas. Para texto pequeño
///   e íconos de alerta se usa [orangeText] (contraste 5.8 sobre [bg]; [orange] solo llega a 3.99).
/// - [cream]: énfasis (wordmark, código de quiniela, puesto, marcadores, foco de campos).
abstract final class StreakColors {
  static const bg = Color(0xFF091A25);
  static const surface1 = Color(0xFF0D2535);
  static const surface2 = Color(0xFF11344A);
  static const line = Color(0xFF1D4763);
  static const brand = Color(0xFF124E73);
  static const brandBorder = Color(0xFF2A6A93);
  static const text = Color(0xFFF2F2F2);
  static const cream = Color(0xFFF2F0CE);
  static const muted = Color(0xFF9FB4C4);
  static const accent = Color(0xFFF2B807);
  static const accentInk = Color(0xFF241A00);
  static const orange = Color(0xFFD9420B);
  static const orangeText = Color(0xFFF26A3D);

  /// Texto de ayuda dentro de los campos (placeholder).
  static const hint = Color(0xFF6D8498);

  /// Fondo de la barra inferior.
  static const navBg = Color(0xFF0B2030);

  /// Velo bajo hojas inferiores, diálogos y panel lateral (#02080E con alfa A3).
  static const scrim = Color(0xA302080E);

  /// Fondo de los avisos de alerta: el mismo [orange] al 12 % (como `.banner` de la maqueta).
  static final orangeTint = orange.withValues(alpha: 0.12);
}
