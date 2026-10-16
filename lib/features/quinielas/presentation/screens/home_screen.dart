import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/server_clock.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/barra_inferior.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/widgets/panel_lateral.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';
import '../../domain/resumen_inicio.dart';
import '../widgets/quiniela_widgets.dart' show horaLocal;

/// Pantallas 07/08 · Inicio: avatar que abre el panel lateral, wordmark, "MIS QUINIELAS" y barra inferior.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BotonPanelLateral(),
        leadingWidth: 64,
        centerTitle: true,
        title: Text(AppConstants.appName, style: StreakText.wordmarkBarra),
      ),
      drawer: const PanelLateral(),
      body: const ListaQuinielas(historial: false),
      bottomNavigationBar: const BarraInferior(activo: DestinoBarra.inicio),
    );
  }
}

/// Lista de quinielas con sus estados (cargando con esqueleto, vacío, error y sin conexión, RN-74).
/// [historial] = true: solo torneos finalizados (lo usa la pantalla Historial).
class ListaQuinielas extends ConsumerWidget {
  const ListaQuinielas({super.key, required this.historial});

  final bool historial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = historial ? historialProvider : misQuinielasProvider;
    final datos = ref.watch(provider);
    final torneos = {for (final t in ref.watch(torneosProvider).valueOrNull ?? const <Torneo>[]) t.id: t};

    Future<void> refrescar() async {
      ref.invalidate(torneosProvider);
      ref.invalidate(provider);
      // Al volver la red también se actualiza el perfil (y desaparece el aviso sin conexión).
      await ref.read(authControllerProvider.notifier).refrescarPerfil().then((_) {}, onError: (_) {});
      await ref.read(provider.future).then((_) {}, onError: (_) {});
    }

    Widget lista(List<Widget> hijos) => RefreshIndicator(
          onRefresh: refrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 0, StreakSize.screenPadding, 24),
            children: hijos,
          ),
        );

    return datos.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => lista([
        if (!historial) const EncabezadoSeccion('Mis quinielas') else const SizedBox(height: 12),
        const EsqueletoTarjetas(),
      ]),
      error: (e, _) {
        final ex = e is AppException ? e : null;
        return EstadoError(
          mensaje: ex?.mensaje ?? 'No se pudieron cargar tus quinielas.',
          sinConexion: ex?.codigo == 'NETWORK_ERROR' || ex?.codigo == 'TIMEOUT_ERROR',
          onReintentar: () => ref.invalidate(provider),
        );
      },
      data: (listado) {
        // En Inicio solo las de torneos no finalizados (las finalizadas viven en Historial). Si los torneos aún no
        // cargaron, se muestran todas.
        final items = historial
            ? listado.items
            : listado.items.where((q) => torneos[q.torneoId]?.esFinalizado != true).toList();
        final offline = listado.offlineDesde;
        final aviso = offline == null
            ? null
            : BannerAviso(icono: StreakIcons.retry, texto: 'Sin conexión · datos de ${horaLocal(offline)}');
        if (items.isEmpty) {
          return lista([
            if (aviso != null) ...[const SizedBox(height: 12), aviso],
            const SizedBox(height: 120),
            historial
                ? const EstadoVacio(
                    titulo: 'Aún no hay historial',
                    texto: 'Aquí aparecerán tus quinielas cuando su torneo finalice.',
                  )
                : EstadoVacio(
                    titulo: 'Aún no tienes quinielas',
                    texto: 'Crea una con tus amigos o únete con un código.',
                    acciones: [
                      BotonPrimario(texto: 'Crear quiniela', onPressed: () => context.push('/quinielas/crear')),
                      BotonSecundario(texto: 'Unirme con código', onPressed: () => context.push('/quinielas/unirse')),
                    ],
                  ),
          ]);
        }
        return lista([
          if (aviso != null) ...[const SizedBox(height: 12), aviso],
          if (!historial) const EncabezadoSeccion('Mis quinielas') else const SizedBox(height: 12),
          for (final q in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TarjetaQuiniela(
                quiniela: q,
                torneo: torneos[q.torneoId],
                historial: historial,
                offline: offline != null,
              ),
            ),
        ]);
      },
    );
  }
}

/// Tarjeta de quiniela (07 y 21): nombre, chip de estado, "torneo · N participantes", PUESTO y PUNTOS.
class TarjetaQuiniela extends ConsumerWidget {
  const TarjetaQuiniela({
    super.key,
    required this.quiniela,
    required this.torneo,
    required this.historial,
    this.offline = false,
  });

  final Quiniela quiniela;
  final Torneo? torneo;
  final bool historial;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quiniela;
    final torneoNombre = q.torneoNombre ?? torneo?.nombre;
    final inscritos = q.cantidadInscritos;
    final meta = [
      if (torneoNombre != null && torneoNombre.isNotEmpty) torneoNombre,
      if (inscritos != null) '$inscritos ${inscritos == 1 ? 'participante' : 'participantes'}',
    ].join(' · ');

    Widget? chip;
    if (historial || torneo?.esFinalizado == true) {
      chip = const ChipStreak('Finalizado', grande: true);
    } else if (!offline && torneo != null) {
      final resumen = ref.watch(resumenPartidosProvider(q.id)).valueOrNull;
      final c = chipInicio(
        torneoActivo: torneo!.esActivo,
        partidos: resumen ?? const [],
        ahoraServidor: ref.watch(serverClockProvider).ahora(),
      );
      chip = switch (c.tipo) {
        TipoChipInicio.ninguno => null,
        TipoChipInicio.enJuego => ChipStreak(c.texto, variante: VarianteChip.live, grande: true),
        TipoChipInicio.cierraPronto => ChipStreak(c.texto, variante: VarianteChip.warn, grande: true),
      };
    }

    final puesto = q.miPosicion == null ? '—' : '${q.miPosicion}.º';
    final puntos = q.misPuntos == null ? '—' : '${q.misPuntos}';
    return Semantics(
      button: true,
      label: '${q.nombre}. ${meta.isEmpty ? '' : '$meta. '}Puesto $puesto, $puntos puntos',
      excludeSemantics: true,
      child: TarjetaStreak(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        onTap: () => context.push('/quinielas/${q.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(q.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: StreakText.tituloTarjeta),
                ),
                if (chip != null) ...[const SizedBox(width: 8), chip],
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(meta, style: StreakText.pequeno),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                DatoCifra(etiqueta: historial ? 'Puesto final' : 'Puesto', valor: puesto),
                const SizedBox(width: 28),
                DatoCifra(etiqueta: 'Puntos', valor: puntos, puntos: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
