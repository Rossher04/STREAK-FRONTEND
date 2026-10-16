import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/models.dart';
import '../widgets/casillas_codigo.dart';
import '../widgets/ingreso_tardio_hoja.dart';

export '../widgets/casillas_codigo.dart' show CodigoFormatter, codigoPermitido;

/// Pantalla 14 · Unirme con código.
/// Flujo: POST /quinielas/validar-codigo/ → si `requiere_confirmacion`, hoja 15 (ingreso tardío)
/// → POST /quinielas/unirse/ (con `aceptar_ingreso_tardio` si se aceptó) → abre la quiniela.
class UnirseQuinielaScreen extends ConsumerStatefulWidget {
  const UnirseQuinielaScreen({super.key});

  @override
  ConsumerState<UnirseQuinielaScreen> createState() => _UnirseQuinielaScreenState();
}

class _UnirseQuinielaScreenState extends ConsumerState<UnirseQuinielaScreen> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codigo.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final code = _codigo.text.trim().toUpperCase();
    if (code.length != largoCodigo) {
      setState(() => _error = 'El código tiene $largoCodigo caracteres.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
    });
    final repo = ref.read(quinielasRepositoryProvider);
    try {
      var v = await repo.validarCodigo(code);
      var aceptar = false;
      if (v.requiereConfirmacion) {
        if (!mounted) return;
        aceptar = await _confirmarIngresoTardio(v);
        if (!aceptar) return;
      }
      try {
        await repo.unirse(code, aceptarIngresoTardio: aceptar);
      } on AppException catch (e) {
        // Carrera: entre la consulta y la unión cerró el primer partido. Se vuelve a consultar y se avisa.
        if (e.codigo != 'CONFIRMACION_INGRESO_TARDIO' || !mounted) rethrow;
        v = await repo.validarCodigo(code);
        if (!mounted) return;
        if (!await _confirmarIngresoTardio(v)) return;
        await repo.unirse(code, aceptarIngresoTardio: true);
      }
      _unido(v);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = mensajeUnirse(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Muestra la hoja 15 sin el indicador de carga detrás; si acepta, lo reactiva.
  Future<bool> _confirmarIngresoTardio(ValidacionCodigo v) async {
    setState(() => _enviando = false);
    final ok = await mostrarIngresoTardio(context, v);
    if (ok && mounted) setState(() => _enviando = true);
    return ok && mounted;
  }

  void _unido(ValidacionCodigo v) {
    refrescarQuinielas(ref);
    if (!mounted) return;
    // unirse/ devuelve el participante, no la quiniela (TODO(backend #15)); el id viene de validar-codigo.
    context.go('/quinielas/${v.quinielaId}');
    avisar(context, 'Te uniste a ${v.nombre}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme con código')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              StreakSize.screenPadding, 16, StreakSize.screenPadding, StreakSize.screenPadding),
          children: [
            Text('Escribe el código que te compartió quien creó la quiniela.',
                style: StreakText.secundario.copyWith(fontSize: StreakText.cuerpo.fontSize)),
            const SizedBox(height: 24),
            CasillasCodigo(
              controller: _codigo,
              conError: _error != null,
              habilitado: !_enviando,
            ),
            const SizedBox(height: 12),
            if (_error == null)
              Text('$largoCodigo caracteres, letras y números', style: StreakText.pequeno)
            else
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StreakIcon(StreakIcons.alert, color: StreakColors.orangeText, size: StreakSize.iconSmall),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, key: const Key('unirse.error'), style: StreakText.error)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            BotonPrimario(texto: 'Continuar', cargando: _enviando, onPressed: _continuar),
          ],
        ),
      ),
    );
  }
}

/// Mensajes claros para los errores de negocio de validar-codigo/ y unirse/ (códigos reales del backend).
String mensajeUnirse(AppException e) {
  switch (e.codigo) {
    case 'QUINIELA_LLENA':
      return 'Esta quiniela ya está llena.';
    case 'YA_PARTICIPA':
      return 'Ya participas en esta quiniela. La encuentras en Inicio.';
    case 'NO_ENCONTRADO':
      return 'No existe ninguna quiniela con ese código. Revísalo con quien te lo compartió.';
    case 'TORNEO_NO_ACTIVO':
      return 'El torneo de esta quiniela ya no admite nuevas inscripciones.';
    case 'CONFIRMACION_INGRESO_TARDIO':
      return 'El torneo ya empezó. Vuelve a intentarlo para confirmar tu ingreso.';
    default:
      return e.mensaje;
  }
}
