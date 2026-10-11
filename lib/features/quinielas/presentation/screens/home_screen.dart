import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_controller.dart';
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
    final user = ref.watch(authControllerProvider).user;
    final ctrl = ref.watch(quinielasControllerProvider.notifier);
    ref.watch(quinielasControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.goldAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primaryBlue),
                accountName: Text(user?.displayName ?? 'Usuario'),
                accountEmail: Text('@${user?.username ?? ''} · solo tú ves correo/teléfono (RN-10)'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.goldAccent,
                  child: Text(
                    (user?.username.isNotEmpty == true) ? user!.username[0].toUpperCase() : 'S',
                    style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                  ),
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
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: AppColors.goldAccent),
                title: const Text('Plan Pro'),
                subtitle: const Text('Día 7 · sin ventaja competitiva'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan Pro se implementa el Día 7 (B6).')),
                  );
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
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _QuinielaList(
            items: ctrl.activas,
            empty: 'Aún no estás en ninguna quiniela activa.',
            historial: false,
          ),
          _QuinielaList(
            items: ctrl.historial,
            empty: 'El historial queda en solo lectura cuando el torneo finaliza (RN-33).',
            historial: true,
          ),
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

class _QuinielaList extends StatelessWidget {
  const _QuinielaList({
    required this.items,
    required this.empty,
    required this.historial,
  });

  final List<Quiniela> items;
  final String empty;
  final bool historial;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final q = items[i];
        return Card(
          child: ListTile(
            title: Text(q.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${q.torneo.nombre}\n${q.puesto}.º de ${q.inscritos} · ${q.puntosUsuario} pts · ${q.codigoUnico}',
            ),
            isThreeLine: true,
            trailing: historial
                ? const Icon(Icons.lock_outline, color: AppColors.textSecondary)
                : const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    historial
                        ? 'Historial de solo lectura (RN-33). Quiniela activa (B5) es Día 5–6.'
                        : 'Quiniela activa (B5) se construye Día 5–6. Puesto: ${q.puesto}.º de ${q.inscritos}.',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
