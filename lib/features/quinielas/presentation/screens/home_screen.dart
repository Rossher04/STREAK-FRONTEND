import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_mobile/core/widgets/streak_icon.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/barra_inferior.dart';
import '../../../auth/presentation/widgets/panel_lateral.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';
import '../widgets/quiniela_widgets.dart';

/// Inicio (07/08): avatar que abre el panel lateral, wordmark y barra inferior.
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

class ListaQuinielas extends ConsumerWidget {
  const ListaQuinielas({super.key, required this.historial});

  final bool historial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = historial ? historialProvider : misQuinielasProvider;
    final datos = ref.watch(provider);
    final torneos = {
      for (final t in ref.watch(torneosProvider).valueOrNull ?? const <Torneo>[]) t.id: t,
    };

    Future<void> refrescar() async {
      ref.invalidate(torneosProvider);
      ref.invalidate(provider);
      // Al volver la red también se actualiza el perfil (y desaparece el aviso sin conexión).
      await ref.read(authControllerProvider.notifier).refrescarPerfil().then((_) {}, onError: (_) {});
      await ref.read(provider.future).then((_) {}, onError: (_) {});
    }

    final lista = RefreshIndicator(
      onRefresh: refrescar,
      child: datos.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => _Mensaje(
          icono: Icons.cloud_off,
          texto: e is AppException ? e.mensaje : 'No se pudieron cargar tus quinielas.',
          acciones: [
            ElevatedButton(onPressed: () => ref.invalidate(provider), child: const Text('REINTENTAR')),
          ],
        ),
        data: (listado) {
          final items = listado.items;
          if (items.isEmpty) {
            return historial
                ? const _Mensaje(
                    icono: Icons.history,
                    texto: 'Aquí aparecerán tus quinielas cuando su torneo finalice (solo lectura, RN-33).',
                  )
                : _Mensaje(
                    icono: Icons.emoji_events_outlined,
                    texto: 'Aún no estás en ninguna quiniela.',
                    acciones: [
                      ElevatedButton(
                        onPressed: () => context.push('/quinielas/crear'),
                        child: const Text('CREAR QUINIELA'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/quinielas/unirse'),
                        child: const Text('UNIRME CON CÓDIGO'),
                      ),
                    ],
                  );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final q = items[i];
              final torneo = torneos[q.torneoId];
              return Card(
                child: ListTile(
                  title: Text(q.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${torneo?.nombre ?? 'Torneo'}\nCódigo ${q.codigoUnico} · máx. ${q.maxParticipantes}',
                  ),
                  isThreeLine: true,
                  trailing: historial
                      ? const Icon(Icons.lock_outline, color: StreakColors.muted)
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/quinielas/${q.id}'),
                ),
              );
            },
          );
        },
      ),
    );

    final offlineDesde = datos.valueOrNull?.offlineDesde;
    if (offlineDesde == null) return lista;
    return Column(
      children: [
        BannerAviso(icono: StreakIcons.retry, texto: 'Sin conexión · datos de ${horaLocal(offlineDesde)}'),
        Expanded(child: lista),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto, this.acciones = const []});

  final IconData icono;
  final String texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icono, size: 56, color: StreakColors.muted),
        const SizedBox(height: 16),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: StreakColors.text)),
        const SizedBox(height: 24),
        for (final a in acciones) Padding(padding: const EdgeInsets.only(bottom: 12), child: a),
      ],
    );
  }
}
