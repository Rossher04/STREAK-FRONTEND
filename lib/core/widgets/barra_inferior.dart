import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/streak_theme.dart';
import 'streak_icon.dart';

/// Ítems de la barra inferior (Inicio, Unirme, Crear, Historial).
enum DestinoBarra { inicio, unirme, crear, historial }

/// Barra inferior de 4 ítems (76 px). Solo en Inicio, Detalle de quiniela e Historial; los formularios no la llevan.
/// El ítem activo lleva ícono y etiqueta en `text` y una barrita amarilla arriba; "Crear" lleva un óvalo `brand`.
class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.activo});

  final DestinoBarra activo;

  void _ir(BuildContext context, DestinoBarra d) {
    switch (d) {
      case DestinoBarra.inicio:
        context.go('/home');
      case DestinoBarra.unirme:
        context.push('/quinielas/unirse');
      case DestinoBarra.crear:
        context.push('/quinielas/crear');
      case DestinoBarra.historial:
        context.go('/historial');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: StreakSize.bottomNavHeight + inferior,
      padding: EdgeInsets.only(bottom: inferior),
      decoration: const BoxDecoration(
        color: StreakColors.navBg,
        border: Border(top: BorderSide(color: StreakColors.line)),
      ),
      child: Row(
        children: [
          _item(context, DestinoBarra.inicio, StreakIcons.home, 'Inicio'),
          _item(context, DestinoBarra.unirme, StreakIcons.joinKey, 'Unirme'),
          _item(context, DestinoBarra.crear, StreakIcons.add, 'Crear'),
          _item(context, DestinoBarra.historial, StreakIcons.history, 'Historial'),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, DestinoBarra d, StreakIcons icono, String etiqueta) {
    final on = d == activo;
    final color = on ? StreakColors.text : StreakColors.muted;
    final crear = d == DestinoBarra.crear;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: etiqueta,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _ir(context, d),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (on)
                Container(
                  width: StreakSize.indicadorBarra,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: StreakColors.accent,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (crear)
                      Container(
                        width: StreakSize.botonCrearAncho,
                        height: StreakSize.botonCrearAlto,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: StreakColors.brand,
                          borderRadius: StreakRadius.pildora,
                          border: Border.all(color: StreakColors.brandBorder),
                        ),
                        child: const StreakIcon(StreakIcons.add, color: StreakColors.text, size: 22),
                      )
                    else
                      StreakIcon(icono, color: color),
                    const SizedBox(height: 4),
                    Text(etiqueta, style: StreakText.mini.copyWith(color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
