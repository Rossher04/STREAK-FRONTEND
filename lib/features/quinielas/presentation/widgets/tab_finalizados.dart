import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/estructura.dart';
import '../../domain/quiniela_vista.dart';
import 'quiniela_widgets.dart';

/// Pestaña "Resultados" (17): partidos resueltos con marcador, mi pronóstico y los puntos del backend.
class TabFinalizados extends StatelessWidget {
  const TabFinalizados({super.key, required this.vista, required this.quinielaId});

  final QuinielaVista vista;
  final int quinielaId;

  @override
  Widget build(BuildContext context) {
    final resueltos = vista.resueltos;
    if (resueltos.isEmpty) return const MensajeVacio('Todavía no hay partidos finalizados.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in resueltos)
          PartidoResueltoCard(
            vista: vista,
            partido: p,
            onTap: () => context.push('/quinielas/$quinielaId/partido/${p.id}'),
          ),
      ],
    );
  }
}

class PartidoResueltoCard extends StatelessWidget {
  const PartidoResueltoCard({super.key, required this.vista, required this.partido, required this.onTap});

  final QuinielaVista vista;
  final Partido partido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = partido;
    final conMarcador = p.estado == 'FINALIZADO' && p.resultado != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaStreak(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${diaLocal(p.fechaHora)} · ${textoEstado(p)}', style: StreakText.pequeno)),
                ChipPuntosPartido(estado: p.estado, puntos: p.puntos),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: EquipoColumna(
                      nombre: vista.nombreEquipo(p.equipoLocalId),
                      escudo: p.equipoLocal?.escudo ?? vista.escudoEquipo(p.equipoLocalId)),
                ),
                Semantics(
                  label: conMarcador ? 'Resultado ${textoMarcador(p.resultado)}' : 'Sin resultado',
                  excludeSemantics: true,
                  child: Text(
                    conMarcador ? textoMarcador(p.resultado) : '– –',
                    style: conMarcador ? StreakText.marcador : StreakText.marcador.copyWith(color: StreakColors.muted),
                  ),
                ),
                Expanded(
                  child: EquipoColumna(
                      nombre: vista.nombreEquipo(p.equipoVisitaId),
                      escudo: p.equipoVisita?.escudo ?? vista.escudoEquipo(p.equipoVisitaId)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Tu pronóstico', style: StreakText.pequeno)),
                Text(
                  p.pronostico == null ? 'Sin pronóstico' : textoMarcador(p.pronostico),
                  style: p.pronostico == null ? StreakText.pequeno : StreakText.cifraFila.copyWith(color: StreakColors.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
