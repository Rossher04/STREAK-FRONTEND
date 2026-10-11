import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/server_clock.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import 'quiniela_widgets.dart';

/// Aviso de eliminatoria (RN-23).
const avisoNoventa =
    "Se pronostica el marcador de los 90' reglamentarios; prórroga y penales no cuentan";

/// Partido pendiente con editor de marcador (steppers 0 a 20, RN-35). La edición se cierra
/// 5 minutos antes del inicio según la hora del servidor (RN-37).
class PartidoPendienteCard extends ConsumerStatefulWidget {
  const PartidoPendienteCard({
    super.key,
    required this.vista,
    required this.partido,
    required this.quinielaId,
    this.onAbrirDetalle,
  });

  final QuinielaVista vista;
  final Partido partido;
  final int quinielaId;
  final VoidCallback? onAbrirDetalle;

  @override
  ConsumerState<PartidoPendienteCard> createState() =>
      _PartidoPendienteCardState();
}

class _PartidoPendienteCardState extends ConsumerState<PartidoPendienteCard> {
  late int _local;
  late int _visita;
  bool _modificado = false;
  bool _guardando = false;
  bool _guardado = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reiniciarDesdePartido();
    // Un tick por segundo solo importa en la última hora (cuenta regresiva y cierre).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final falta = cierreDe(widget.partido.fechaHora).difference(_ahora());
      if (mounted && falta.abs() <= const Duration(hours: 1)) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PartidoPendienteCard old) {
    super.didUpdateWidget(old);
    if (!_modificado && old.partido.pronostico != widget.partido.pronostico) {
      _reiniciarDesdePartido();
    }
  }

  void _reiniciarDesdePartido() {
    _local = widget.partido.pronostico?.local ?? 0;
    _visita = widget.partido.pronostico?.visita ?? 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _ahora() => ref.read(serverClockProvider).ahora();

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await ref.read(quinielasRepositoryProvider).guardarPronostico(
            widget.quinielaId,
            widget.partido.id,
            Marcador(_local, _visita),
          );
      if (!mounted) return;
      setState(() {
        _modificado = false;
        _guardado = true;
      });
      ref.invalidate(quinielaVistaProvider(widget.quinielaId));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
      // Si el servidor ya cerró (PRONOSTICOS_CERRADOS) se refresca para mostrar el estado real.
      if (e.codigo == 'PRONOSTICOS_CERRADOS' ||
          e.codigo == 'TORNEO_NO_ACTIVO') {
        ref.invalidate(quinielaVistaProvider(widget.quinielaId));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vista;
    final p = widget.partido;
    final ahora = _ahora();
    final editable = puedeEditarPronostico(
      estadoPartido: p.estado,
      fechaHora: p.fechaHora,
      ahoraServidor: ahora,
      torneoFinalizado: v.torneoFinalizado,
    );
    final fase = v.fases[p.faseId];
    final cuenta = editable ? cuentaRegresiva(p.fechaHora, ahora) : null;
    final puedeGuardar = editable &&
        !v.offline &&
        !_guardando &&
        (_modificado || p.pronostico == null);

    String estadoTexto;
    if (v.torneoFinalizado) {
      estadoTexto = 'Quiniela finalizada · solo lectura';
    } else if (p.estado == 'EN_JUEGO') {
      estadoTexto = 'En juego · pronósticos cerrados';
    } else if (!editable) {
      estadoTexto =
          'Cerrado · los pronósticos cierran $minutosCierre min antes';
    } else {
      estadoTexto = 'Cierra a las ${horaLocal(cierreDe(p.fechaHora))}';
    }

    return Card(
      child: InkWell(
        onTap: editable ? null : widget.onAbrirDetalle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fechaLocal(p.fechaHora),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (editable)
                Row(
                  children: [
                    Expanded(
                        child: _Lado(
                            nombre: v.nombreEquipo(p.equipoLocalId),
                            valor: _local,
                            activo: editable,
                            fijo: p.pronostico?.local,
                            onCambio: (n) => setState(() {
                                  _local = n;
                                  _modificado = true;
                                  _guardado = false;
                                }))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                        child: _Lado(
                            nombre: v.nombreEquipo(p.equipoVisitaId),
                            valor: _visita,
                            activo: editable,
                            fijo: p.pronostico?.visita,
                            onCambio: (n) => setState(() {
                                  _visita = n;
                                  _modificado = true;
                                  _guardado = false;
                                }))),
                  ],
                ),
              if (!editable)
                Row(
                  children: [
                    Expanded(
                      child: Text(v.nombreEquipo(p.equipoLocalId),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('vs',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(v.nombreEquipo(p.equipoVisitaId),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                cuenta != null ? '$estadoTexto · faltan $cuenta' : estadoTexto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cuenta != null
                      ? AppColors.sportsOrange
                      : AppColors.textSecondary,
                  fontWeight:
                      cuenta != null ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              if (fase?.esEliminatoria == true) ...[
                const SizedBox(height: 4),
                const Text(
                  avisoNoventa,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.sportsOrange, fontSize: 11),
                ),
              ],
              if (!editable) ...[
                const SizedBox(height: 8),
                Text(
                  p.pronostico == null
                      ? 'No pronosticaste'
                      : 'Tu pronóstico: ${textoMarcador(p.pronostico)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ] else ...[
                const SizedBox(height: 10),
                if (v.offline)
                  const Text(
                    'Sin conexión: no se puede guardar',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  )
                else
                  ElevatedButton(
                    onPressed: puedeGuardar ? _guardar : null,
                    child: Text(_guardando
                        ? 'GUARDANDO…'
                        : (_guardado || (!_modificado && p.pronostico != null))
                            ? 'GUARDADO ✓'
                            : 'GUARDAR PRONÓSTICO'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado({
    required this.nombre,
    required this.valor,
    required this.activo,
    required this.onCambio,
    this.fijo,
  });

  final String nombre;
  final int valor;
  final bool activo;
  final ValueChanged<int> onCambio;

  /// Goles ya guardados que se muestran cuando no se puede editar.
  final int? fijo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (!activo)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(fijo == null ? '–' : '$fijo',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Restar gol a $nombre',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: activo && valor > golesMin
                    ? () => onCambio(valor - 1)
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text('$valor',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Sumar gol a $nombre',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: activo && valor < golesMax
                    ? () => onCambio(valor + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}
