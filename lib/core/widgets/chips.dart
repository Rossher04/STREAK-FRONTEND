import 'package:flutter/material.dart';

import '../theme/streak_theme.dart';
import 'streak_icon.dart';

enum VarianteChip {
  /// Fondo `surface2`, texto secundario.
  neutro,

  /// Neutro con punto naranja ("En juego").
  live,

  /// Borde naranja con punto ("Cierra en…").
  warn,

  /// Borde amarillo y texto amarillo (PRO, "+5").
  pro,

  /// Fondo `surface2` y texto `text` (+4, +3).
  destacado,

  /// Solo borde `line` (0 puntos, "Cerrado").
  contorno,
}

/// Chip en forma de píldora (11 px). El color siempre sale del tema.
class ChipStreak extends StatelessWidget {
  const ChipStreak(this.texto, {super.key, this.variante = VarianteChip.neutro, this.icono, this.grande = false});

  final String texto;
  final VarianteChip variante;
  final StreakIcons? icono;

  /// Variante de 13 px (chips de estado de las tarjetas).
  final bool grande;

  /// Chip de puntos de un partido: +5 amarillo, +4/+3 neutro destacado, 0 solo borde.
  factory ChipStreak.puntos(int puntos, {Key? key}) => ChipStreak(
        puntos > 0 ? '+$puntos' : '0',
        key: key,
        variante: puntos == 5
            ? VarianteChip.pro
            : puntos > 0
                ? VarianteChip.destacado
                : VarianteChip.contorno,
      );

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, color) = switch (variante) {
      VarianteChip.neutro => (StreakColors.surface2, null, StreakColors.muted),
      VarianteChip.live => (StreakColors.surface2, null, StreakColors.muted),
      VarianteChip.warn => (Colors.transparent, StreakColors.orange, StreakColors.text),
      VarianteChip.pro => (Colors.transparent, StreakColors.accent, StreakColors.accent),
      VarianteChip.destacado => (StreakColors.surface2, null, StreakColors.text),
      VarianteChip.contorno => (Colors.transparent, StreakColors.line, StreakColors.muted),
    };
    final estilo = (grande ? StreakText.pequeno : StreakText.mini).copyWith(color: color, height: 1.2);
    final punto = variante == VarianteChip.live || variante == VarianteChip.warn;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: grande ? 12 : 8, vertical: grande ? 5 : 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: StreakRadius.pildora,
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto) ...[
            Container(
              width: StreakSize.puntoEstado,
              height: StreakSize.puntoEstado,
              decoration: const BoxDecoration(color: StreakColors.orange, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icono != null) ...[
            StreakIcon(icono!, color: color, size: grande ? StreakSize.iconChip : StreakSize.iconMini),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(texto, style: estilo, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
