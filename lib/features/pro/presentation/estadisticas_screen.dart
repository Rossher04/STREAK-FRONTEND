import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/icono_pro.dart';
import '../../auth/application/auth_controller.dart';
import '../../quinielas/application/quinielas_providers.dart';
import '../../quinielas/domain/quiniela_vista.dart';
import '../../quinielas/presentation/widgets/quiniela_widgets.dart';
import '../domain/pro_reglas.dart';

/// "Mis estadísticas" (solo PRO). Con datos que ya entrega la API: mis pronósticos y puntos.
class EstadisticasScreen extends ConsumerWidget {
  const EstadisticasScreen({super.key, required this.quinielaId});

  final int quinielaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final datos = ref.watch(quinielaVistaProvider(quinielaId));

    if (!puedeVerEstadisticas(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis estadísticas')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconoPro(radio: 32, icono: Icons.lock_outline),
                const SizedBox(height: 16),
                const Text('Las estadísticas avanzadas son parte del plan PRO.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.push('/pro'), child: const Text('VER PLAN PRO')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis estadísticas')),
      body: datos.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(quinielaVistaProvider(quinielaId))),
        data: (v) => _Contenido(vista: v, usuarioId: user!.id),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.vista, required this.usuarioId});

  final QuinielaVista vista;
  final int usuarioId;

  @override
  Widget build(BuildContext context) {
    final e = calcularEstadisticas(partidos: vista.partidos, tabla: vista.tabla, usuarioId: usuarioId);
    final efectividad = e.efectividad;
    final dif = e.diferenciaConPromedio;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (vista.offline)
          BannerAviso(icono: Icons.wifi_off, texto: 'Sin conexión · datos de ${horaLocal(vista.offlineDesde!)}'),
        Text(vista.quiniela.nombre, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _Dato(
          clave: const ValueKey('efectividad'),
          titulo: 'Efectividad',
          valor: efectividad == null ? '—' : '${efectividad.toStringAsFixed(0)} %',
          detalle: e.resueltosConPronostico == 0
              ? 'Aún no hay partidos finalizados en los que hayas pronosticado.'
              : '${e.conPuntos} de ${e.resueltosConPronostico} partidos con puntos',
        ),
        _Dato(
          clave: const ValueKey('racha'),
          titulo: 'Racha actual',
          valor: '${e.rachaActual}',
          detalle: 'partidos seguidos sumando puntos · mejor racha: ${e.mejorRacha}',
        ),
        _Dato(
          clave: const ValueKey('exactos'),
          titulo: 'Marcadores exactos',
          valor: '${e.exactos}',
          detalle: 'aciertos de 5 puntos',
        ),
        _Dato(
          clave: const ValueKey('comparativa'),
          titulo: 'Tus puntos vs. el promedio',
          valor: '${e.misPuntos} pts',
          detalle: e.promedioTabla == null
              ? 'Sin datos de la tabla.'
              : 'Promedio de la quiniela: ${e.promedioTabla!.toStringAsFixed(1)} pts'
                  ' (${dif! >= 0 ? '+' : ''}${dif.toStringAsFixed(1)})',
        ),
        const SizedBox(height: 8),
        const Text(
          'Solo cuentan los partidos finalizados. Un partido sin pronóstico vale 0 y rompe la racha.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.clave, required this.titulo, required this.valor, required this.detalle});

  final Key clave;
  final String titulo;
  final String valor;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(detalle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                ],
              ),
            ),
            Text(valor,
                key: clave,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
          ],
        ),
      ),
    );
  }
}
