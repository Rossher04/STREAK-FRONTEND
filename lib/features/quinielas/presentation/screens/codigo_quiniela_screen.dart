import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';

class CodigoQuinielaScreen extends ConsumerWidget {
  const CodigoQuinielaScreen({super.key, required this.quinielaId});

  final int quinielaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiniela = ref.watch(quinielaProvider(quinielaId));
    final torneos = ref.watch(torneosProvider).valueOrNull ?? const <Torneo>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Código de la quiniela')),
      body: quiniela.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is AppException ? e.mensaje : 'No se pudo cargar la quiniela.', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(quinielaProvider(quinielaId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (q) {
          final torneo = torneos.where((t) => t.id == q.torneoId).firstOrNull;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(q.nombre, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (torneo != null)
                  Text(torneo.nombre, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    q.codigoUnico,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hasta ${q.maxParticipantes} participantes. Comparte este código para que se unan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => Share.share(
                    'Únete a mi quiniela STREAK "${q.nombre}" con el código ${q.codigoUnico}. No rompas la racha.',
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('COMPARTIR (WHATSAPP / OTROS)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('IR AL INICIO'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
