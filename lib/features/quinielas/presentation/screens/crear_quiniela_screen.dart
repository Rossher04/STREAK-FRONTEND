import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';
import '../widgets/resumen_puntaje.dart';

/// Formato del torneo en lenguaje llano ("Apertura 2026 · Liga").
String formatoTorneo(String formato) => switch (formato) {
      'LIGA' => 'Liga',
      'GRUPOS_ELIMINATORIA' => 'Grupos y eliminatoria',
      'ELIMINATORIA' => 'Eliminatoria',
      _ => formato,
    };

/// Pantalla 12 · Crear quiniela: nombre, torneo ACTIVO (RN-16), sistema de puntaje y tope de
/// participantes 2–50 (2–100 con Pro, RN-26). El backend valida el tope y su error se muestra tal cual.
class CrearQuinielaScreen extends ConsumerStatefulWidget {
  const CrearQuinielaScreen({super.key});

  @override
  ConsumerState<CrearQuinielaScreen> createState() => _CrearQuinielaScreenState();
}

class _CrearQuinielaScreenState extends ConsumerState<CrearQuinielaScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  int? _torneoId;
  double _max = 12;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _esPro => ref.watch(authControllerProvider.select((s) => s.user?.esPro ?? false));

  int get _tope => _esPro ? AppConstants.maxParticipantesPro : AppConstants.maxParticipantesGratis;

  Future<void> _crear(Torneo torneo, int maximo) async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _creando = true);
    try {
      final q = await ref.read(quinielasRepositoryProvider).crear(
            nombre: _nombre.text.trim(),
            torneoId: torneo.id,
            maxParticipantes: maximo,
          );
      refrescarQuinielas(ref);
      if (mounted) context.go('/quinielas/${q.id}/codigo');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final torneos = ref.watch(torneosActivosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear quiniela')),
      body: SafeArea(
        child: torneos.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(StreakSize.screenPadding),
            child: EsqueletoTarjetas(cantidad: 2),
          ),
          error: (e, _) => EstadoError(
            mensaje: e is AppException ? e.mensaje : 'No se pudieron cargar los torneos.',
            sinConexion: e is AppException && e.codigo == 'NETWORK_ERROR',
            onReintentar: () => ref.invalidate(torneosProvider),
          ),
          data: (lista) => lista.isEmpty
              ? const EstadoVacio(
                  titulo: 'No hay torneos activos',
                  texto: 'Por ahora no se puede crear una quiniela. Vuelve a intentarlo más tarde.',
                )
              : _formulario(lista),
        ),
      ),
    );
  }

  Widget _formulario(List<Torneo> lista) {
    final torneo = lista.firstWhere((t) => t.id == _torneoId, orElse: () => lista.first);
    final tope = _tope;
    const minimo = AppConstants.minParticipantes;
    final maximo = _max.clamp(minimo.toDouble(), tope.toDouble()).round();

    return Form(
      key: _form,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(StreakSize.screenPadding, 12, StreakSize.screenPadding, StreakSize.screenPadding),
        children: [
          CampoTexto(
            etiqueta: 'Nombre de la quiniela',
            controller: _nombre,
            hint: 'Ej. Liga Amigos',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 3) return 'Escribe al menos 3 caracteres.';
              if (t.length > 255) return 'Máximo 255 caracteres.';
              return null;
            },
          ),
          const SizedBox(height: 18),
          ExcludeSemantics(child: Text('Torneo', style: StreakText.etiqueta)),
          const SizedBox(height: 6),
          // Un solo nodo "Torneo, <valor>" separado del deslizador y del botón.
          MergeSemantics(
            child: Semantics(
              label: 'Torneo',
              child: DropdownButtonFormField<int>(
                key: ValueKey(torneo.id),
                initialValue: torneo.id,
                isExpanded: true,
                dropdownColor: StreakColors.surface1,
                borderRadius: StreakRadius.campo,
                icon: const StreakIcon(StreakIcons.chevronDown, color: StreakColors.muted),
                style: StreakText.cuerpo,
                items: lista
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.nombre} · ${formatoTorneo(t.formato)}', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (id) => setState(() => _torneoId = id),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const ResumenPuntaje(),
          const SizedBox(height: 10),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Máximo de participantes', style: StreakText.etiqueta),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Participantes: $maximo',
                        excludeSemantics: true,
                        child: Text('$maximo', key: const Key('crear.maximo'), style: StreakText.cifraGrande),
                      ),
                    ),
                    if (!_esPro)
                      GestureDetector(
                        onTap: () => context.push('/pro'),
                        child: const ChipStreak(
                          'Hasta ${AppConstants.maxParticipantesPro} con Pro',
                          variante: VarianteChip.pro,
                          icono: StreakIcons.crownPro,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  min: minimo.toDouble(),
                  max: tope.toDouble(),
                  divisions: tope - minimo,
                  value: maximo.toDouble(),
                  label: '$maximo',
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  semanticFormatterCallback: (v) => '${v.round()} participantes',
                  onChanged: (v) => setState(() => _max = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$minimo', style: StreakText.pequeno),
                    Text('$tope', style: StreakText.pequeno),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StreakIcon(StreakIcons.alert, color: StreakColors.orangeText, size: StreakSize.iconSmall),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, key: const Key('crear.error'), style: StreakText.error)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: BotonPrimario(
              texto: 'Crear quiniela',
              cargando: _creando,
              onPressed: () => _crear(torneo, maximo),
            ),
          ),
        ],
      ),
    );
  }
}
