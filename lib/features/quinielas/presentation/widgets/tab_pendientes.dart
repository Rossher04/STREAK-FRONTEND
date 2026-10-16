import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/server_clock.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import 'partido_pendiente_card.dart';
import 'quiniela_widgets.dart';

/// Texto del único botón amarillo de la pestaña.
const textoGuardarPronosticos = 'Guardar pronósticos';

/// Resultado de guardar varios pronósticos: cuántos se guardaron y el motivo de cada fallo.
typedef ResultadoGuardado = ({int guardados, Map<int, String> fallos});

/// Envía cada pronóstico cambiado con un POST por partido. Un fallo no detiene a los demás:
/// devuelve el motivo de cada uno para mostrarlo en su tarjeta sin perder lo escrito.
Future<ResultadoGuardado> guardarVarios(
  Future<void> Function(int partidoId, Marcador m) guardar,
  Map<int, Marcador> cambios,
) async {
  final fallos = <int, String>{};
  var guardados = 0;
  for (final e in cambios.entries) {
    try {
      await guardar(e.key, e.value);
      guardados++;
    } on AppException catch (err) {
      fallos[e.key] = err.codigo == 'PRONOSTICOS_CERRADOS'
          ? 'No se guardó: el plazo para este partido ya cerró.'
          : 'No se guardó: ${err.mensaje}';
    }
  }
  return (guardados: guardados, fallos: fallos);
}

/// Pestaña "Pendientes" (16): partidos PROGRAMADO y EN_JUEGO agrupados por fase, con casillas de
/// goles y UN solo botón "Guardar pronósticos" que envía todos los cambiados.
class TabPendientes extends ConsumerStatefulWidget {
  const TabPendientes({super.key, required this.vista, required this.quinielaId});

  final QuinielaVista vista;
  final int quinielaId;

  @override
  ConsumerState<TabPendientes> createState() => _TabPendientesState();
}

class _TabPendientesState extends ConsumerState<TabPendientes> {
  final _local = <int, TextEditingController>{};
  final _visita = <int, TextEditingController>{};

  /// Partidos que el usuario tocó desde el último guardado correcto.
  final _editados = <int>{};
  Map<int, String> _errores = {};
  bool _guardando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sincronizar(forzar: true);
    // El chip "Cierra en…" y el cierre a 5 min dependen del reloj: se repinta cada 15 s.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TabPendientes old) {
    super.didUpdateWidget(old);
    _sincronizar();
  }

  /// Copia los pronósticos del servidor a las casillas que el usuario no está editando.
  void _sincronizar({bool forzar = false}) {
    for (final p in widget.vista.pendientes) {
      final l = _local.putIfAbsent(p.id, TextEditingController.new);
      final v = _visita.putIfAbsent(p.id, TextEditingController.new);
      if (forzar || !_editados.contains(p.id)) {
        l.text = p.pronostico?.local.toString() ?? '';
        v.text = p.pronostico?.visita.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [..._local.values, ..._visita.values]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _ahora() => ref.read(serverClockProvider).ahora();

  bool _editable(Partido p, DateTime ahora) => puedeEditarPronostico(
        estadoPartido: p.estado,
        fechaHora: p.fechaHora,
        ahoraServidor: ahora,
        torneoFinalizado: widget.vista.torneoFinalizado,
        cierreServidor: p.cierrePronosticos,
        abiertoServidor: p.pronosticosAbiertos,
      );

  Future<void> _guardar() async {
    final ahora = _ahora();
    final cambios = <int, Marcador>{};
    final errores = <int, String>{};
    for (final p in widget.vista.pendientes) {
      if (!_editados.contains(p.id) || !_editable(p, ahora)) continue;
      final l = int.tryParse(_local[p.id]!.text);
      final v = int.tryParse(_visita[p.id]!.text);
      if (l == null && v == null) continue;
      if (l == null || v == null) {
        errores[p.id] = 'Completa los dos marcadores.';
        continue;
      }
      final m = Marcador(l, v);
      if (m != p.pronostico) cambios[p.id] = m;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (cambios.isEmpty) {
      setState(() => _errores = errores);
      if (errores.isNotEmpty) _avisar(messenger, 'Revisa los marcadores marcados.');
      return;
    }
    setState(() {
      _guardando = true;
      _errores = errores;
    });
    final repo = ref.read(quinielasRepositoryProvider);
    final r = await guardarVarios((id, m) => repo.guardarPronostico(widget.quinielaId, id, m), cambios);
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _errores = {...errores, ...r.fallos};
      _editados.removeWhere((id) => cambios.containsKey(id) && !r.fallos.containsKey(id));
    });
    if (r.fallos.isEmpty) {
      _avisar(messenger, r.guardados == 1 ? 'Pronóstico guardado.' : '${r.guardados} pronósticos guardados.');
    } else {
      final nombres = r.fallos.keys.map((id) {
        final p = widget.vista.partidos.firstWhere((x) => x.id == id);
        return '${widget.vista.nombreEquipo(p.equipoLocalId)} – ${widget.vista.nombreEquipo(p.equipoVisitaId)}';
      }).join(', ');
      _avisar(messenger, 'Se guardaron ${r.guardados} de ${cambios.length}. No se guardó: $nombres.');
    }
    // Se recarga para mostrar lo que quedó en el servidor (y los partidos que ya cerraron).
    ref.invalidate(quinielaVistaProvider(widget.quinielaId));
  }

  void _avisar(ScaffoldMessengerState? m, String texto) {
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vista;
    final ahora = ref.watch(serverClockProvider).ahora();
    final grupos = agruparPorFase(v, v.pendientes);
    if (grupos.isEmpty) {
      return MensajeVacio(v.torneoFinalizado
          ? 'El torneo terminó: no quedan partidos por pronosticar.'
          : 'No hay partidos pendientes por ahora.');
    }
    final hayEditables = v.pendientes.any((p) => _editable(p, ahora));
    final hayCambios = _editados.any((id) {
      final p = v.pendientes.where((x) => x.id == id);
      return p.isNotEmpty && _editable(p.first, ahora);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (fase, partidos) in grupos) ...[
          EncabezadoFase(fase, eliminatoria: partidos.any(v.esEliminatoria)),
          for (final p in partidos)
            PartidoPendienteCard(
              key: ValueKey(p.id),
              vista: v,
              partido: p,
              ahora: ahora,
              editable: _editable(p, ahora),
              local: _local[p.id]!,
              visita: _visita[p.id]!,
              error: _errores[p.id],
              onCambio: () => setState(() {
                _editados.add(p.id);
                _errores.remove(p.id);
              }),
              onAbrirDetalle: () => context.push('/quinielas/${widget.quinielaId}/partido/${p.id}'),
            ),
        ],
        if (hayEditables) ...[
          const SizedBox(height: 4),
          BotonPrimario(
            texto: _guardando ? 'Guardando…' : textoGuardarPronosticos,
            cargando: _guardando,
            onPressed: (v.offline || _guardando || !hayCambios) ? null : _guardar,
          ),
          if (v.offline) ...[
            const SizedBox(height: 8),
            Text('Sin conexión: no se puede guardar', textAlign: TextAlign.center, style: StreakText.pequeno),
          ],
        ],
      ],
    );
  }
}
