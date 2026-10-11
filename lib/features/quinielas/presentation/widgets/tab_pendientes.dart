import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/quiniela_vista.dart';
import 'partido_pendiente_card.dart';
import 'quiniela_widgets.dart';

/// Pestaña "Pendientes": partidos por jugar (PROGRAMADO y EN_JUEGO), agrupados por fase.
class TabPendientes extends StatelessWidget {
  const TabPendientes({super.key, required this.vista, required this.quinielaId, required this.onRefresh});

  final QuinielaVista vista;
  final int quinielaId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final grupos = agruparPorFase(vista, vista.pendientes);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: grupos.isEmpty
          ? ListaVacia(
              icono: Icons.event_available,
              texto: vista.torneoFinalizado
                  ? 'El torneo terminó: no quedan partidos por pronosticar.'
                  : 'No hay partidos pendientes por ahora.',
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final (fase, partidos) in grupos) ...[
                  EncabezadoFase(fase),
                  for (final p in partidos)
                    PartidoPendienteCard(
                      key: ValueKey(p.id),
                      vista: vista,
                      partido: p,
                      quinielaId: quinielaId,
                      onAbrirDetalle: () => context.push('/quinielas/$quinielaId/partido/${p.id}'),
                    ),
                ],
              ],
            ),
    );
  }
}
