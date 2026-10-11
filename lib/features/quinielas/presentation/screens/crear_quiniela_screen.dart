import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';
import '../widgets/scoring_banner.dart';

class CrearQuinielaScreen extends ConsumerStatefulWidget {
  const CrearQuinielaScreen({super.key});

  @override
  ConsumerState<CrearQuinielaScreen> createState() => _CrearQuinielaScreenState();
}

class _CrearQuinielaScreenState extends ConsumerState<CrearQuinielaScreen> {
  final _nombre = TextEditingController();
  int? _torneoId;
  double _max = 12;
  bool _creando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  int get _tope {
    final esPro = ref.read(authControllerProvider).user?.esPro ?? false;
    return esPro ? AppConstants.maxParticipantesPro : AppConstants.maxParticipantesGratis;
  }

  Future<void> _crear(List<Torneo> torneos) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nombre.text.trim().length < 3) {
      messenger.showSnackBar(const SnackBar(content: Text('El nombre debe tener al menos 3 caracteres')));
      return;
    }
    final torneoId = _torneoId ?? (torneos.isNotEmpty ? torneos.first.id : null);
    if (torneoId == null) return;
    setState(() => _creando = true);
    try {
      final q = await ref.read(quinielasRepositoryProvider).crear(
            nombre: _nombre.text.trim(),
            torneoId: torneoId,
            maxParticipantes: _max
                .clamp(AppConstants.minParticipantes.toDouble(), _tope.toDouble())
                .round(),
          );
      refrescarQuinielas(ref);
      if (mounted) context.go('/quinielas/${q.id}/codigo');
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final torneos = ref.watch(torneosActivosProvider);
    final tope = _tope;
    final max = _max.clamp(AppConstants.minParticipantes.toDouble(), tope.toDouble());

    return Scaffold(
      appBar: AppBar(title: const Text('Crear quiniela')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ScoringBanner(),
          const SizedBox(height: 20),
          TextField(
            controller: _nombre,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Nombre de la quiniela'),
          ),
          const SizedBox(height: 8),
          torneos.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Column(
              children: [
                Text(
                  e is AppException ? e.mensaje : 'No se pudieron cargar los torneos.',
                  style: const TextStyle(color: AppColors.error),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(torneosProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay torneos activos por ahora. Vuelve a intentarlo más tarde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              final actual = lista.firstWhere(
                (t) => t.id == _torneoId,
                orElse: () => lista.first,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(actual.id),
                    initialValue: actual.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Torneo (solo ACTIVO, RN-16)'),
                    items: lista
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text('${t.nombre} · ${t.temporada}', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (id) => setState(() => _torneoId = id),
                  ),
                  const SizedBox(height: 8),
                  if (actual.formato == 'GRUPOS_ELIMINATORIA')
                    const Text(
                      'En eliminatoria solo cuenta el tiempo reglamentario (90\'). Prórroga y penales no puntúan (RN-23).',
                      style: TextStyle(color: AppColors.sportsOrange, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  Text('Participantes: ${max.round()} (mín. ${AppConstants.minParticipantes}, máx. $tope)'),
                  Slider(
                    min: AppConstants.minParticipantes.toDouble(),
                    max: tope.toDouble(),
                    divisions: tope - AppConstants.minParticipantes,
                    value: max,
                    label: '${max.round()}',
                    onChanged: (v) => setState(() => _max = v),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _creando ? null : () => _crear(lista),
                    child: Text(_creando ? 'CREANDO…' : 'CREAR Y VER CÓDIGO'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
