import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';

const _exacto = AppConstants.puntosMarcadorExacto;
const _resultado = AppConstants.puntosGanadorCorrecto;
const _diferencia = AppConstants.puntosGanadorCorrecto + AppConstants.puntosDiferenciaGolesExtra;

/// Línea compacta del sistema de puntaje (RN-45 a RN-47) con un ⓘ que abre el detalle.
/// El enunciado exige mostrar el puntaje al crear la quiniela.
class ResumenPuntaje extends StatelessWidget {
  const ResumenPuntaje({super.key});

  static const texto = 'Exacto $_exacto · Resultado y diferencia $_diferencia · Resultado $_resultado';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(texto, style: StreakText.pequeno)),
        IconButton(
          tooltip: 'Ver sistema de puntaje',
          onPressed: () => mostrarSistemaPuntaje(context),
          icon: const StreakIcon(StreakIcons.info, color: StreakColors.muted, size: StreakSize.iconSmall),
        ),
      ],
    );
  }
}

/// Hoja inferior con el detalle del sistema de puntaje.
Future<void> mostrarSistemaPuntaje(BuildContext context) {
  Widget fila(int puntos, String titulo, String detalle) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft, child: ChipStreak.puntos(puntos))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: StreakText.cuerpoMedio),
                  Text(detalle, style: StreakText.pequeno),
                ],
              ),
            ),
          ],
        ),
      );
  return mostrarHoja<void>(
    context,
    titulo: 'Sistema de puntaje',
    texto: 'Cada partido suma según tu pronóstico. Gana quien acumule más puntos.',
    contenido: (ctx) => [
      fila(_exacto, 'Marcador exacto', 'Aciertas los goles de los dos equipos.'),
      fila(_diferencia, 'Resultado y diferencia',
          'Aciertas quién gana (o el empate) y la diferencia de goles: $_resultado + ${AppConstants.puntosDiferenciaGolesExtra}.'),
      fila(_resultado, 'Resultado', 'Aciertas quién gana o que hay empate.'),
      fila(AppConstants.puntosFallo, 'Fallo o sin pronóstico', 'No suma puntos.'),
      Text(
        'Los pronósticos cierran 5 minutos antes de cada partido. En eliminatoria solo cuenta el tiempo '
        'reglamentario (90\'): prórroga y penales no puntúan.',
        style: StreakText.pequeno,
      ),
    ],
  );
}
