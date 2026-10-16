import 'package:flutter/material.dart';

import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../domain/models.dart';

/// Texto del aviso de ingreso tardío según cuántos partidos ya cerraron (RN-31).
/// No hay descuento de puntos: el backend devuelve `penalizacion_puntos = 0`.
String textoIngresoTardio(int cerrados) => cerrados == 1
    ? 'El partido que ya cerró cuenta 0 puntos para ti. Puedes pronosticar los que faltan.'
    : 'Los $cerrados partidos que ya cerraron cuentan 0 puntos para ti. Puedes pronosticar los que faltan.';

/// Pantalla 15 · Hoja inferior "Este torneo ya empezó". Devuelve true si la persona acepta.
Future<bool> mostrarIngresoTardio(BuildContext context, ValidacionCodigo v) async {
  final ok = await mostrarHoja<bool>(
    context,
    titulo: 'Este torneo ya empezó',
    texto: textoIngresoTardio(v.partidosCerrados),
    contenido: (ctx) => [
      TarjetaStreak(
        key: const Key('tardio.tarjeta'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(v.nombre, style: StreakText.tituloTarjeta, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                ChipStreak('${v.cantidadInscritos} de ${v.maxParticipantes}', grande: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${v.torneoNombre} · ${v.partidosCerrados} '
              '${v.partidosCerrados == 1 ? 'partido cerrado' : 'partidos cerrados'}',
              style: StreakText.pequeno,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      BotonPrimario(texto: 'Unirme de todos modos', onPressed: () => Navigator.of(ctx).pop(true)),
      const SizedBox(height: 12),
      BotonSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(ctx).pop(false)),
    ],
  );
  return ok ?? false;
}
