import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import 'quiniela_widgets.dart';

/// Ancho de la casilla de goles: el de la maqueta, pero nunca menos que el mínimo táctil (48 dp).
const _anchoCasilla = StreakSize.cajaGolesAncho > kMinInteractiveDimension
    ? StreakSize.cajaGolesAncho
    : kMinInteractiveDimension;

/// Solo enteros de [golesMin] a [golesMax] (RN-35): se rechaza lo que se salga del rango.
class GolesFormatter extends TextInputFormatter {
  const GolesFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final n = int.tryParse(t);
    if (n == null || n < golesMin || n > golesMax || t.length > 2) return oldValue;
    return newValue;
  }
}

/// Chip de estado de un partido pendiente: "En juego", "Cierra en 1 h 20 min" (borde naranja),
/// "Cierra mié 14 · 11:55" (neutro, falta más de un día) o "Cerrado" (candado).
Widget chipPendiente(Partido p, {required bool editable, required DateTime ahora}) {
  if (p.enJuego) return const ChipStreak('En juego', variante: VarianteChip.live, grande: true);
  if (!editable) {
    return const ChipStreak('Cerrado', variante: VarianteChip.contorno, icono: StreakIcons.lock, grande: true);
  }
  final pronto = textoCierraEn(p.cierre, ahora);
  if (pronto != null) return ChipStreak(pronto, variante: VarianteChip.warn, grande: true);
  return ChipStreak(textoCierre(cierre: p.cierre, ahora: ahora), grande: true);
}

/// Tarjeta de partido pendiente (16): fecha local, chip de cierre, escudos y casillas de goles 0–20.
/// El estado (borradores, errores) lo lleva la pestaña: aquí solo se pinta.
class PartidoPendienteCard extends StatelessWidget {
  const PartidoPendienteCard({
    super.key,
    required this.vista,
    required this.partido,
    required this.ahora,
    required this.editable,
    required this.local,
    required this.visita,
    this.error,
    this.onCambio,
    this.onAbrirDetalle,
  });

  final QuinielaVista vista;
  final Partido partido;
  final DateTime ahora;
  final bool editable;
  final TextEditingController local;
  final TextEditingController visita;

  /// Motivo por el que no se guardó este pronóstico (se conserva lo escrito).
  final String? error;
  final VoidCallback? onCambio;
  final VoidCallback? onAbrirDetalle;

  @override
  Widget build(BuildContext context) {
    final p = partido;
    final nLocal = vista.nombreEquipo(p.equipoLocalId);
    final nVisita = vista.nombreEquipo(p.equipoVisitaId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaStreak(
        onTap: editable ? null : onAbrirDetalle,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const StreakIcon(StreakIcons.calendar, size: StreakSize.iconChip),
                const SizedBox(width: 6),
                Expanded(child: Text(fechaLocal(p.fechaHora), style: StreakText.pequeno)),
                const SizedBox(width: 8),
                chipPendiente(p, editable: editable, ahora: ahora),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: EquipoColumna(nombre: nLocal, escudo: p.equipoLocal?.escudo ?? vista.escudoEquipo(p.equipoLocalId))),
                _Casilla(equipo: nLocal, controller: local, editable: editable, fijo: p.pronostico?.local, onCambio: onCambio),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–', style: StreakText.cajaGoles.copyWith(color: StreakColors.muted)),
                ),
                _Casilla(equipo: nVisita, controller: visita, editable: editable, fijo: p.pronostico?.visita, onCambio: onCambio),
                Expanded(child: EquipoColumna(nombre: nVisita, escudo: p.equipoVisita?.escudo ?? vista.escudoEquipo(p.equipoVisitaId))),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StreakIcon(StreakIcons.alert, size: StreakSize.iconMini, color: StreakColors.orangeText),
                  const SizedBox(width: 6),
                  Expanded(child: Text(error!, style: StreakText.error)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.equipo, required this.controller, required this.editable, this.fijo, this.onCambio});

  final String equipo;
  final TextEditingController controller;
  final bool editable;

  /// Goles ya guardados que se muestran cuando no se puede editar.
  final int? fijo;
  final VoidCallback? onCambio;

  @override
  Widget build(BuildContext context) {
    if (!editable) {
      return Semantics(
        label: 'Tu pronóstico para $equipo',
        value: fijo == null ? 'sin pronóstico' : '$fijo',
        excludeSemantics: true,
        child: Container(
          width: _anchoCasilla,
          height: StreakSize.cajaGolesAlto,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StreakColors.bg,
            borderRadius: StreakRadius.campo,
            border: Border.all(color: StreakColors.line),
          ),
          child: Text(fijo == null ? '–' : '$fijo', style: StreakText.cajaGoles.copyWith(color: StreakColors.muted)),
        ),
      );
    }
    final borde = OutlineInputBorder(
      borderRadius: StreakRadius.campo,
      borderSide: const BorderSide(color: StreakColors.cream),
    );
    return SizedBox(
      width: _anchoCasilla,
      height: StreakSize.cajaGolesAlto,
      child: Semantics(
        label: 'Goles de $equipo',
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          style: StreakText.cajaGoles,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, const GolesFormatter()],
          onChanged: (_) => onCambio?.call(),
          decoration: InputDecoration(
            filled: true,
            fillColor: StreakColors.bg,
            hintText: '–',
            contentPadding: EdgeInsets.zero,
            enabledBorder: borde,
            focusedBorder: borde.copyWith(borderSide: const BorderSide(color: StreakColors.cream, width: 2)),
            border: borde,
          ),
        ),
      ),
    );
  }
}
