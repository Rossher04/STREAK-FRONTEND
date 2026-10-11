import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/quiniela_vista.dart';
import 'quiniela_widgets.dart';

/// Pestaña "Tabla": posiciones (empates comparten puesto), el usuario actual resaltado.
///
/// El backend no envía foto ni es_pro por participante en /tabla/ (ParticipanteSerializer),
/// por eso solo se muestra inicial del username y no hay badge Pro.
class TabTabla extends StatelessWidget {
  const TabTabla({
    super.key,
    required this.vista,
    required this.quinielaId,
    required this.usuarioId,
    required this.onRefresh,
  });

  final QuinielaVista vista;
  final int quinielaId;
  final int? usuarioId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: vista.tabla.isEmpty
          ? const ListaVacia(icono: Icons.leaderboard_outlined, texto: 'Aún no hay participantes en la tabla.')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vista.tabla.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = vista.tabla[i];
                final yo = f.usuarioId == usuarioId;
                return ListTile(
                  selected: yo,
                  selectedTileColor: AppColors.goldAccent.withValues(alpha: 0.18),
                  leading: SizedBox(
                    width: 64,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text('${f.posicion}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.creamBackground,
                          child: Text(
                            f.username.isEmpty ? '?' : f.username[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(yo ? '${f.username} (tú)' : f.username,
                      style: TextStyle(fontWeight: yo ? FontWeight.w800 : FontWeight.w600)),
                  trailing: Text('${f.puntos} pts', style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => context.push('/quinielas/$quinielaId/participante/${f.usuarioId}'),
                );
              },
            ),
    );
  }
}
