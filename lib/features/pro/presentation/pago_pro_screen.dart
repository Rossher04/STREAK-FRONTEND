import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/streak_theme.dart';
import '../../../core/widgets/botones.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/estructura.dart';
import '../../../core/widgets/marca.dart';
import '../../../core/widgets/streak_icon.dart';
import '../application/pago_pro_controller.dart';
import '../data/pro_repository.dart';
import 'pro_textos.dart';

/// Pantalla 23 · Pago (resumen + hoja de Stripe) y, al terminar, pantalla 24 · Pago confirmado
/// (o sus variantes "En revisión" y error). La tarjeta la pide SOLO la hoja de Stripe.
class PagoProScreen extends ConsumerStatefulWidget {
  const PagoProScreen({super.key});

  @override
  ConsumerState<PagoProScreen> createState() => _PagoProScreenState();
}

class _PagoProScreenState extends ConsumerState<PagoProScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(pagoProControllerProvider.notifier).revisarPendiente();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pago = ref.watch(pagoProControllerProvider);
    final ctrl = ref.read(pagoProControllerProvider.notifier);
    final estadoPro = ref.watch(estadoProProvider);

    if (pago.esResultado) {
      return Scaffold(
        body: SafeArea(
          child: ResultadoPago(
            estado: pago,
            maxParticipantes: estadoPro.valueOrNull?.maxParticipantes ?? 100,
            onListo: () => context.go('/home'),
            onReintentar: ctrl.pagar,
            onComprobar: ctrl.verificar,
            onCancelarPendiente: ctrl.cancelarPendiente,
            onVolver: ctrl.volverAlResumen,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar Plan Pro')),
      body: SafeArea(
        top: false,
        child: estadoPro.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(StreakSize.screenPadding),
            child: EsqueletoTarjetas(cantidad: 1),
          ),
          error: (e, _) => EstadoError(
            mensaje: e is AppException ? e.mensaje : 'No se pudo cargar el precio del plan.',
            sinConexion: e is AppException && (e.codigo == 'NETWORK_ERROR' || e.codigo == 'TIMEOUT_ERROR'),
            onReintentar: () => ref.invalidate(estadoProProvider),
          ),
          data: (e) => ResumenPago(
            plan: e,
            estado: pago,
            motivoNoDisponible: ref.watch(motivoPagosNoDisponiblesProvider),
            onPagar: ctrl.pagar,
            onCancelarPendiente: ctrl.cancelarPendiente,
          ),
        ),
      ),
    );
  }
}

/// Contenido de la pantalla 23. RN-65: precio, periodo y cómo cancelar quedan ANTES del botón
/// que abre la hoja de Stripe (único lugar donde se pide la tarjeta).
class ResumenPago extends StatelessWidget {
  const ResumenPago({
    super.key,
    required this.plan,
    required this.estado,
    required this.motivoNoDisponible,
    required this.onPagar,
    required this.onCancelarPendiente,
  });

  final EstadoPro plan;
  final EstadoPago estado;
  final String? motivoNoDisponible;
  final VoidCallback onPagar;
  final VoidCallback onCancelarPendiente;

  @override
  Widget build(BuildContext context) {
    final pendiente = estado.pendiente;
    return ListView(
      padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 16, StreakSize.screenPadding, 24),
      children: [
        TarjetaStreak(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan Pro', style: StreakText.tituloTarjeta),
                    const SizedBox(height: 4),
                    Text(
                      'Hasta ${plan.maxParticipantes} participantes · insignia dorada · estadísticas',
                      style: StreakText.pequeno,
                    ),
                    const SizedBox(height: 4),
                    Text(textoPagoUnico, key: const ValueKey('periodo'), style: StreakText.pequeno),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(plan.importe, key: const ValueKey('precio'), style: StreakText.precioResumen),
            ],
          ),
        ),
        if (plan.modoPrueba) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: ChipStreak('Modo de prueba · sin cobros reales'),
          ),
        ],
        const SizedBox(height: 14),
        Text(textoComoCancelar, key: const ValueKey('cancelar'), style: StreakText.pequeno),
        const SizedBox(height: 8),
        Text(textoStripe, style: StreakText.secundario),
        if (pendiente != null) ...[
          const SizedBox(height: 14),
          BannerAviso(
            key: const ValueKey('aviso-pendiente'),
            icono: StreakIcons.timer,
            neutro: true,
            texto: 'Tienes una compra pendiente del '
                '${DateFormat("d MMM yyyy", 'es').format(pendiente.pago.fecha.toLocal())} '
                '(\$${pendiente.pago.monto} ${pendiente.pago.moneda}). "Pagar" la retoma sin un segundo cobro.',
          ),
          const SizedBox(height: 10),
          BotonDestructivo(
            key: const ValueKey('boton-cancelar-pendiente'),
            texto: 'Cancelar compra pendiente',
            onPressed: estado.ocupado ? null : onCancelarPendiente,
          ),
        ],
        if (motivoNoDisponible != null) ...[
          const SizedBox(height: 14),
          BannerAviso(key: const ValueKey('motivo-no-disponible'), texto: motivoNoDisponible!),
        ],
        if (estado.mensaje != null) ...[
          const SizedBox(height: 14),
          Text(estado.mensaje!, key: const ValueKey('mensaje-pago'), style: StreakText.cuerpoMedio),
        ],
        const SizedBox(height: 20),
        BotonPrimario(
          key: const ValueKey('boton-pagar'),
          texto: switch (estado.fase) {
            FasePago.procesando => 'Procesando…',
            FasePago.activando => 'Confirmando pago…',
            _ => 'Pagar ${plan.importeConMoneda}',
          },
          cargando: estado.ocupado,
          onPressed: motivoNoDisponible != null ? null : onPagar,
        ),
        const SizedBox(height: 8),
        EnlaceTexto(
          key: const ValueKey('enlace-condiciones'),
          texto: textoEnlaceCondiciones,
          subrayado: true,
          onPressed: () => mostrarCondicionesPro(context, plan),
        ),
      ],
    );
  }
}

/// Pantalla 24 · Pago confirmado, con sus variantes "En revisión" y error.
class ResultadoPago extends StatelessWidget {
  const ResultadoPago({
    super.key,
    required this.estado,
    required this.maxParticipantes,
    required this.onListo,
    required this.onReintentar,
    required this.onComprobar,
    required this.onCancelarPendiente,
    required this.onVolver,
  });

  final EstadoPago estado;
  final int maxParticipantes;
  final VoidCallback onListo;
  final VoidCallback onReintentar;
  final VoidCallback onComprobar;
  final VoidCallback onCancelarPendiente;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final (Widget ilustracion, String titulo, String texto, List<Widget> acciones) = switch (estado.fase) {
      FasePago.enRevision => (
          const StreakIcon(StreakIcons.timer, size: StreakSize.avatarGrande, color: StreakColors.muted),
          'Pago en revisión',
          estado.mensaje ?? mensajeEnRevision,
          [
            BotonPrimario(key: const ValueKey('boton-comprobar'), texto: 'Comprobar de nuevo', onPressed: onComprobar),
            if (estado.pendiente != null)
              BotonDestructivo(
                key: const ValueKey('boton-cancelar-pendiente'),
                texto: 'Cancelar compra pendiente',
                onPressed: onCancelarPendiente,
              ),
            BotonSecundario(texto: 'Volver al inicio', onPressed: onListo),
          ],
        ),
      FasePago.error => (
          const StreakIcon(StreakIcons.alert, size: StreakSize.avatarGrande, color: StreakColors.orangeText),
          'No se pudo completar el pago',
          estado.mensaje ?? 'Ocurrió un error. No se hizo ningún cobro.',
          [
            BotonPrimario(
                key: const ValueKey('boton-reintentar'),
                texto: 'Reintentar',
                icono: StreakIcons.retry,
                onPressed: onReintentar),
            BotonSecundario(texto: 'Volver', onPressed: onVolver),
          ],
        ),
      _ => (
          const EstelaIlustracion(ancho: 122),
          '¡Ya eres PRO!',
          'Tus quinielas ahora admiten hasta $maxParticipantes participantes y tu insignia dorada '
              'aparece en la tabla.',
          [BotonPrimario(key: const ValueKey('boton-listo'), texto: 'Listo', onPressed: onListo)],
        ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(StreakSize.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ilustracion),
            const SizedBox(height: 32),
            Semantics(
              header: true,
              child: Text(titulo, key: const ValueKey('titulo-resultado'), textAlign: TextAlign.center,
                  style: StreakText.tituloGrande),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(texto, textAlign: TextAlign.center, style: StreakText.secundario),
            ),
            const SizedBox(height: 28),
            for (final a in acciones) Padding(padding: const EdgeInsets.only(bottom: 12), child: a),
          ],
        ),
      ),
    );
  }
}
