import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/barra_inferior.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/reglas.dart';
import '../../domain/resumen_quiniela.dart';
import '../widgets/quiniela_widgets.dart';

/// Historial (21): quinielas de torneos FINALIZADOS (`GET /quinielas/historial/`), solo lectura (RN-33),
/// con el resumen del backend (torneo, inscritos, puesto final y puntos). Barra inferior con Historial activo.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(historialResumenProvider);

    Future<void> refrescar() async {
      ref.invalidate(historialResumenProvider);
      await ref.read(historialResumenProvider.future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: StreakSize.screenPadding,
        title: Text('Historial', style: StreakText.tituloGrande),
      ),
      bottomNavigationBar: const BarraInferior(activo: DestinoBarra.historial),
      body: datos.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const CargandoTarjetas(alto: 132),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(historialResumenProvider)),
        data: (listado) => RefreshIndicator(
          onRefresh: refrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
            children: [
              if (listado.offline) ...[
                BannerAviso(icono: StreakIcons.retry, texto: 'Sin conexión · datos de ${horaLocal(listado.offlineDesde!)}'),
                const SizedBox(height: 12),
              ],
              if (listado.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: EstadoVacio(
                    titulo: 'Aún no hay historial',
                    texto: 'Aquí aparecerán tus quinielas cuando su torneo finalice. Podrás consultarlas en modo '
                        'solo lectura.',
                  ),
                ),
              for (final q in listado.items)
                TarjetaHistorial(resumen: q, onTap: () => context.push('/quinielas/${q.id}')),
            ],
          ),
        ),
      ),
    );
  }
}

class TarjetaHistorial extends StatelessWidget {
  const TarjetaHistorial({super.key, required this.resumen, this.onTap});

  final ResumenQuiniela resumen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final q = resumen;
    final n = q.cantidadInscritos;
    final subtitulo = [
      // TODO(backend #13): sin torneo_nombre (backend anterior a a86fe6d) solo se muestra el código.
      q.torneoNombre ?? 'Código ${q.codigo}',
      if (n != null) '$n ${n == 1 ? 'participante' : 'participantes'}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaStreak(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(q.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: StreakText.tituloGrande),
                ),
                const SizedBox(width: 8),
                const ChipStreak('Finalizado', grande: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitulo, style: StreakText.secundario),
            const SizedBox(height: 12),
            Row(
              children: [
                DatoCifra(
                    etiqueta: 'Puesto final', valor: q.miPosicion == null ? '—' : etiquetaPuesto(q.miPosicion!)),
                const SizedBox(width: 40),
                DatoCifra(etiqueta: 'Puntos', valor: q.misPuntos == null ? '—' : '${q.misPuntos}', puntos: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
