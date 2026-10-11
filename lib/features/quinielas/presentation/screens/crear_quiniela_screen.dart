import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/quinielas_controller.dart';
import '../../data/mock_catalog.dart';
import '../../domain/models.dart';
import '../widgets/scoring_banner.dart';

class CrearQuinielaScreen extends ConsumerStatefulWidget {
  const CrearQuinielaScreen({super.key});

  @override
  ConsumerState<CrearQuinielaScreen> createState() => _CrearQuinielaScreenState();
}

class _CrearQuinielaScreenState extends ConsumerState<CrearQuinielaScreen> {
  final _nombre = TextEditingController();
  late Torneo _torneo;
  double _max = 12;
  bool _esPro = false;

  @override
  void initState() {
    super.initState();
    _torneo = MockCatalog.activos.first;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  int get _tope => _esPro ? AppConstants.maxParticipantesPro : AppConstants.maxParticipantesGratis;

  void _crear() {
    if (_nombre.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre debe tener al menos 3 caracteres')),
      );
      return;
    }
    final q = ref.read(quinielasControllerProvider.notifier).crear(
          nombre: _nombre.text.trim(),
          torneo: _torneo,
          maxParticipantes: _max.round(),
        );
    context.go('/quinielas/${q.id}/codigo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear quiniela')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ScoringBanner(),
          const SizedBox(height: 20),
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre de la quiniela'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Torneo>(
            key: ValueKey(_torneo.id),
            initialValue: _torneo,
            decoration: const InputDecoration(labelText: 'Torneo (solo ACTIVO, RN-16)'),
            items: MockCatalog.activos
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text('${t.nombre} · ${t.formato}'),
                  ),
                )
                .toList(),
            onChanged: (t) {
              if (t != null) setState(() => _torneo = t);
            },
          ),
          const SizedBox(height: 8),
          if (_torneo.formato == 'GRUPOS_ELIMINATORIA')
            const Text(
              'En eliminatoria solo cuenta el tiempo reglamentario (90\'). Prórroga y penales no puntúan (RN-23).',
              style: TextStyle(color: AppColors.sportsOrange, fontSize: 12),
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simular Plan Pro (tope 100)'),
            value: _esPro,
            onChanged: (v) {
              setState(() {
                _esPro = v;
                if (_max > _tope) _max = _tope.toDouble();
              });
            },
          ),
          Text('Participantes: ${_max.round()} (mín. ${AppConstants.minParticipantes}, máx. $_tope)'),
          Slider(
            min: AppConstants.minParticipantes.toDouble(),
            max: _tope.toDouble(),
            divisions: _tope - AppConstants.minParticipantes,
            value: _max.clamp(
              AppConstants.minParticipantes.toDouble(),
              _tope.toDouble(),
            ),
            label: '${_max.round()}',
            onChanged: (v) => setState(() => _max = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _crear, child: const Text('CREAR Y VER CÓDIGO')),
        ],
      ),
    );
  }
}
