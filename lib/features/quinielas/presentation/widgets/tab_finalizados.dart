import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/quiniela_vista.dart';
import 'quiniela_widgets.dart';

/// Pestaña "Finalizados": resultado real, mi pronóstico y puntos de los partidos resueltos.
class TabFinalizados extends StatelessWidget {
  const TabFinalizados({super.key, required this.vista, required this.quinielaId, required this.onRefresh});

  final QuinielaVista vista;
  final int quinielaId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final grupos = agruparPorFase(vista, vista.resueltos);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: grupos.isEmpty
          ? const ListaVacia(icono: Icons.sports_soccer, texto: 'Todavía no hay partidos finalizados.')
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final (fase, partidos) in grupos) ...[
                  EncabezadoFase(fase),
                  for (final p in partidos)
                    PartidoResueltoCard(
                      vista: vista,
                      partido: p,
                      onTap: () => context.push('/quinielas/$quinielaId/partido/${p.id}'),
                    ),
                ],
              ],
            ),
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
    final sinResultado = p.estado != 'FINALIZADO';
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Text(
                '${fechaLocal(p.fechaHora)} · ${textoEstado(p)}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(vista.nombreEquipo(p.equipoLocalId),
                        textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      sinResultado ? 'vs' : textoMarcador(p.resultado),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    child: Text(vista.nombreEquipo(p.equipoVisitaId),
                        textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p.pronostico == null ? 'No pronosticaste' : 'Mi pronóstico: ${textoMarcador(p.pronostico)}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              EtiquetaPuntosChip(p),
            ],
          ),
        ),
      ),
    );
  }
}
