import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.goldAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Mis quinielas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      drawer: const _HomeDrawer(),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _QuinielaList(historial: false),
          _QuinielaList(historial: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.sportsOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
        onPressed: () => _showCreateSheet(context),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_events, color: AppColors.primaryBlue),
              title: const Text('Crear quiniela'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/quinielas/crear');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: AppColors.sportsOrange),
              title: const Text('Unirse con código'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/quinielas/unirse');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final foto = user?.fotoUrl;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primaryBlue),
              accountName: Row(
                children: [
                  Flexible(child: Text(user?.displayName ?? '', overflow: TextOverflow.ellipsis)),
                  if (user?.esPro == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              accountEmail: Text('@${user?.username ?? ''}'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.goldAccent,
                backgroundImage: foto != null ? NetworkImage(foto) : null,
                child: foto == null
                    ? Text(
                        (user?.username.isNotEmpty == true) ? user!.username[0].toUpperCase() : '',
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                context.push('/perfil');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Cerrar sesión'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuinielaList extends ConsumerWidget {
  const _QuinielaList({required this.historial});

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
      await ref.read(provider.future).catchError((_) => <Quiniela>[]);
    }

    return RefreshIndicator(
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
        data: (items) {
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
                      ? const Icon(Icons.lock_outline, color: AppColors.textSecondary)
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/quinielas/${q.id}/codigo'),
                ),
              );
            },
          );
        },
      ),
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
        Icon(icono, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        for (final a in acciones) Padding(padding: const EdgeInsets.only(bottom: 12), child: a),
      ],
    );
  }
}
