import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import '../widgets/quiniela_widgets.dart';
import '../widgets/tab_finalizados.dart';
import '../widgets/tab_pendientes.dart';
import '../widgets/tab_tabla.dart';

/// B5: quiniela activa. Encabezado (torneo, quiniela, puesto y puntos) y pestañas.
class QuinielaActivaScreen extends ConsumerWidget {
  const QuinielaActivaScreen({super.key, required this.quinielaId});

  final int quinielaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(quinielaVistaProvider(quinielaId));

    Future<void> refrescar() async {
      ref.invalidate(quinielaVistaProvider(quinielaId));
      await ref.read(quinielaVistaProvider(quinielaId).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiniela'),
        actions: [
          IconButton(
            tooltip: 'Mis estadísticas',
            icon: Icon(
              Icons.insights,
              color: ref.watch(authControllerProvider.select((s) => s.user?.esPro ?? false))
                  ? AppColors.goldAccent
                  : null,
            ),
            // No PRO: la pantalla de estadísticas muestra el acceso al paywall.
            onPressed: () => context.push('/quinielas/$quinielaId/estadisticas'),
          ),
          IconButton(
            tooltip: 'Ver y compartir código',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: () => context.push('/quinielas/$quinielaId/codigo'),
          ),
        ],
      ),
      body: datos.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorReintentar(
          error: e,
          onRetry: () => ref.invalidate(quinielaVistaProvider(quinielaId)),
        ),
        data: (v) => _Contenido(vista: v, quinielaId: quinielaId, onRefresh: refrescar),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.vista, required this.quinielaId, required this.onRefresh});

  final QuinielaVista vista;
  final int quinielaId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Encabezado(vista: vista, usuarioId: usuarioId),
          if (vista.offline)
            BannerAviso(
              icono: Icons.wifi_off,
              texto: 'Sin conexión · datos de ${horaLocal(vista.offlineDesde!)}',
            ),
          if (vista.torneoFinalizado)
            const BannerAviso(
              icono: Icons.lock_outline,
              texto: 'Quiniela finalizada · solo lectura',
              color: AppColors.primaryBlue,
            ),
          const TabBar(
            labelColor: AppColors.primaryBlue,
            indicatorColor: AppColors.sportsOrange,
            tabs: [Tab(text: 'Pendientes'), Tab(text: 'Finalizados'), Tab(text: 'Tabla')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TabPendientes(vista: vista, quinielaId: quinielaId, onRefresh: onRefresh),
                TabFinalizados(vista: vista, quinielaId: quinielaId, onRefresh: onRefresh),
                TabTabla(vista: vista, quinielaId: quinielaId, usuarioId: usuarioId, onRefresh: onRefresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Torneo, quiniela, puesto "3.º de 12" (RN-53) y puntos del usuario, tomados de la tabla.
class Encabezado extends StatelessWidget {
  const Encabezado({super.key, required this.vista, required this.usuarioId});

  final QuinielaVista vista;
  final int? usuarioId;

  @override
  Widget build(BuildContext context) {
    final fila = usuarioId == null ? null : vista.filaDe(usuarioId!);
    return Container(
      width: double.infinity,
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vista.torneo.nombre, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  vista.quiniela.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fila == null ? '—' : etiquetaPuesto(fila.posicion, vista.tabla.length),
                key: const ValueKey('puesto'),
                style: const TextStyle(color: AppColors.goldAccent, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                fila == null ? '' : '${fila.puntos} pts',
                key: const ValueKey('puntos'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
