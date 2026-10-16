import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/estructura.dart';
import '../../domain/quiniela_vista.dart';
import 'quiniela_widgets.dart';

/// Pestaña "Tabla" (19): puesto con empates compartidos (1, 1, 3) tal como lo envía el backend,
/// avatar con foto o iniciales, corona si es PRO y la fila propia con borde crema y "(tú)".
class TabTabla extends StatelessWidget {
  const TabTabla({super.key, required this.vista, required this.quinielaId, required this.usuarioId});

  final QuinielaVista vista;
  final int quinielaId;
  final int? usuarioId;

  @override
  Widget build(BuildContext context) {
    if (vista.tabla.isEmpty) return const MensajeVacio('Aún no hay participantes en la tabla.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in vista.tabla)
          FilaTablaWidget(
            fila: f,
            esYo: f.usuarioId == usuarioId,
            onTap: () => context.push('/quinielas/$quinielaId/participante/${f.usuarioId}'),
          ),
      ],
    );
  }
}

class FilaTablaWidget extends StatelessWidget {
  const FilaTablaWidget({super.key, required this.fila, required this.esYo, this.onTap});

  final FilaTabla fila;
  final bool esYo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = fila;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: onTap != null,
        label: 'Puesto ${f.posicion}, ${f.username}${f.esPro ? ', PRO' : ''}${esYo ? ', tú' : ''}, ${f.puntos} puntos',
        excludeSemantics: true,
        child: TarjetaStreak(
          onTap: onTap,
          resaltada: esYo,
          radio: StreakRadius.fila,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text('${f.posicion}',
                    key: ValueKey('posicion-${f.usuarioId}'),
                    style: StreakText.posicion.copyWith(color: esYo || f.posicion == 1 ? StreakColors.cream : null)),
              ),
              AvatarUsuario(nombre: f.username, fotoUrl: f.foto),
              const SizedBox(width: 12),
              Expanded(child: NombreParticipante(nombre: f.username, esPro: f.esPro, esYo: esYo)),
              const SizedBox(width: 8),
              Text('${f.puntos}', style: StreakText.cifraFila),
            ],
          ),
        ),
      ),
    );
  }
}
