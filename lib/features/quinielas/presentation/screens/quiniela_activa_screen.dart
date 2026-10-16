import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/barra_inferior.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import '../widgets/quiniela_widgets.dart';
import '../widgets/tab_finalizados.dart';
import '../widgets/tab_pendientes.dart';
import '../widgets/tab_tabla.dart';

/// Detalle de quiniela (16 Pendientes, 17 Resultados, 19 Tabla): cabecera con puesto y puntos,
/// pestañas segmentadas y barra inferior con Inicio activo.
class QuinielaActivaScreen extends ConsumerStatefulWidget {
  const QuinielaActivaScreen({super.key, required this.quinielaId, this.pestanaInicial = 0});

  final int quinielaId;

  /// 0 Pendientes, 1 Resultados, 2 Tabla.
  final int pestanaInicial;

  @override
  ConsumerState<QuinielaActivaScreen> createState() => _QuinielaActivaScreenState();
}

class _QuinielaActivaScreenState extends ConsumerState<QuinielaActivaScreen> {
  late int _pestana = widget.pestanaInicial;

  @override
  Widget build(BuildContext context) {
    final id = widget.quinielaId;
    final datos = ref.watch(quinielaVistaProvider(id));
    final usuarioId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    final esPro = ref.watch(authControllerProvider.select((s) => s.user?.esPro ?? false));

    Future<void> refrescar() async {
      ref.invalidate(quinielaVistaProvider(id));
      await ref.read(quinielaVistaProvider(id).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(datos.valueOrNull?.quiniela.nombre ?? 'Quiniela', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Mis estadísticas',
            // No PRO: la pantalla de estadísticas muestra el acceso al plan.
            icon: StreakIcon(StreakIcons.trophy, color: esPro ? StreakColors.accent : StreakColors.text),
            onPressed: () => context.push('/quinielas/$id/estadisticas'),
          ),
          IconButton(
            tooltip: 'Sistema de puntaje',
            icon: const StreakIcon(StreakIcons.info, color: StreakColors.text),
            onPressed: () => mostrarSistemaPuntaje(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const BarraInferior(activo: DestinoBarra.inicio),
      body: datos.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const CargandoTarjetas(),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(quinielaVistaProvider(id))),
        data: (v) => RefreshIndicator(
          onRefresh: refrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
            children: [
              if (v.offline) ...[
                BannerAviso(icono: StreakIcons.retry, texto: 'Sin conexión · datos de ${horaLocal(v.offlineDesde!)}'),
                const SizedBox(height: 12),
              ],
              if (v.torneoFinalizado) ...[
                const BannerAviso(icono: StreakIcons.lock, texto: 'Quiniela finalizada · solo lectura', neutro: true),
                const SizedBox(height: 12),
              ],
              CabeceraQuiniela(vista: v, usuarioId: usuarioId),
              const SizedBox(height: 16),
              PestanasSegmentadas(
                opciones: const ['Pendientes', 'Resultados', 'Tabla'],
                indice: _pestana,
                onCambio: (i) => setState(() => _pestana = i),
              ),
              const SizedBox(height: 16),
              // Las tres se mantienen montadas para no perder lo escrito al cambiar de pestaña.
              Offstage(offstage: _pestana != 0, child: TabPendientes(vista: v, quinielaId: id)),
              Offstage(offstage: _pestana != 1, child: TabFinalizados(vista: v, quinielaId: id)),
              Offstage(offstage: _pestana != 2, child: TabTabla(vista: v, quinielaId: id, usuarioId: usuarioId)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera: nombre, torneo · N participantes, código, "En juego", PUESTO (crema) y PUNTOS (amarillo).
/// Puesto y puntos salen del resumen del backend (`mi_posicion` / `mis_puntos`) o, si falta, de `/tabla/`.
class CabeceraQuiniela extends StatelessWidget {
  const CabeceraQuiniela({super.key, required this.vista, required this.usuarioId});

  final QuinielaVista vista;
  final int? usuarioId;

  @override
  Widget build(BuildContext context) {
    final v = vista;
    final puesto = v.miPuesto(usuarioId);
    final puntos = v.misPuntos(usuarioId);
    final n = v.inscritos;
    return TarjetaStreak(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(v.quiniela.nombre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: StreakText.tituloGrande),
              ),
              if (v.hayEnJuego) ...[
                const SizedBox(width: 8),
                const ChipStreak('En juego', variante: VarianteChip.live, grande: true),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('${v.torneoNombre} · $n ${n == 1 ? 'participante' : 'participantes'}',
                    style: StreakText.secundario),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Código ${v.quiniela.codigoUnico}, ver y compartir',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: StreakRadius.pildora,
                  onTap: () => context.push('/quinielas/${v.quiniela.id}/codigo'),
                  child: ChipStreak(v.quiniela.codigoUnico, grande: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            excludeSemantics: true,
            label: puesto == null ? 'Tu puesto no está disponible' : 'Tu puesto: ${etiquetaPuesto(puesto)}, ${puntos ?? 0} puntos',
            child: Row(
              children: [
                DatoCifra(etiqueta: 'Puesto', valor: puesto == null ? '—' : etiquetaPuesto(puesto), valorKey: const ValueKey('puesto')),
                const SizedBox(width: 28),
                DatoCifra(etiqueta: 'Puntos', valor: '${puntos ?? 0}', puntos: true, valorKey: const ValueKey('puntos')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
