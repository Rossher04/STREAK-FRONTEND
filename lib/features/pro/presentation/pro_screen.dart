import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/streak_theme.dart';
import '../../../core/widgets/botones.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/estructura.dart';
import '../../../core/widgets/icono_pro.dart';
import '../../../core/widgets/streak_icon.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pago_pro_controller.dart';
import '../data/pro_repository.dart';
import 'pro_textos.dart';

/// Ruta de la pantalla de pago (23 y su resultado 24).
const rutaPagoPro = '/pro/pago';

/// Pantalla 22 · Plan Pro. Sin PRO: precio de GET /pro/estado/, beneficios reales y "Obtener Plan Pro".
/// Con PRO: "Tu plan PRO" con el historial de GET /pro/pagos/.
class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esProUsuario = ref.watch(authControllerProvider.select((s) => s.user?.esPro ?? false));
    final estado = ref.watch(estadoProProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Pro')),
      body: SafeArea(
        top: false,
        child: estado.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(StreakSize.screenPadding),
            child: EsqueletoTarjetas(cantidad: 2),
          ),
          error: (e, _) => EstadoError(
            mensaje: e is AppException ? e.mensaje : 'No se pudo cargar el plan.',
            sinConexion: e is AppException && (e.codigo == 'NETWORK_ERROR' || e.codigo == 'TIMEOUT_ERROR'),
            onReintentar: () => ref.invalidate(estadoProProvider),
          ),
          data: (e) => (esProUsuario || e.esPro) ? TuPlanPro(estado: e) : PlanProContenido(estado: e),
        ),
      ),
    );
  }
}

/// Contenido de la pantalla 22 (sin PRO).
class PlanProContenido extends StatelessWidget {
  const PlanProContenido({super.key, required this.estado});

  final EstadoPro estado;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 28, StreakSize.screenPadding, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(estado.importeCorto, key: const ValueKey('precio'), style: StreakText.precio),
            const SizedBox(width: 8),
            Text(estado.moneda, style: StreakText.tituloGrande.copyWith(color: StreakColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        Text(textoPagoUnico, key: const ValueKey('periodo'), style: StreakText.cuerpoMedio),
        const SizedBox(height: 4),
        Text(
          'Más espacio y estadísticas para tus quinielas. '
          'El plan gratis llega a ${estado.maxParticipantesGratis} participantes.',
          style: StreakText.secundario,
        ),
        const SizedBox(height: 14),
        ListaBeneficios(estado: estado),
        const SizedBox(height: 16),
        BotonPrimario(
          key: const ValueKey('boton-obtener'),
          texto: 'Obtener Plan Pro',
          onPressed: () => context.push(rutaPagoPro),
        ),
        const SizedBox(height: 8),
        EnlaceTexto(
          key: const ValueKey('enlace-condiciones'),
          texto: textoEnlaceCondiciones,
          subrayado: true,
          onPressed: () => mostrarCondicionesPro(context, estado),
        ),
      ],
    );
  }
}

/// "Tu plan PRO": estado activo, beneficios e historial de pagos.
class TuPlanPro extends ConsumerWidget {
  const TuPlanPro({super.key, required this.estado});

  final EstadoPro estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagos = ref.watch(pagosProProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pagosProProvider);
        await ref.read(pagosProProvider.future).then((_) {}, onError: (_) {});
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 24, StreakSize.screenPadding, 24),
        children: [
          Row(
            children: [
              const IconoPro(radio: 24),
              const SizedBox(width: 14),
              Expanded(child: Text('Tu plan PRO', style: StreakText.tituloGrande)),
              const ChipStreak('Activo', variante: VarianteChip.pro),
            ],
          ),
          const SizedBox(height: 10),
          Text(textoPagoUnico, style: StreakText.secundario),
          const SizedBox(height: 10),
          ListaBeneficios(estado: estado),
          const EncabezadoSeccion('Historial de pagos'),
          pagos.when(
            loading: () => const EsqueletoTarjetas(cantidad: 1),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(e is AppException ? e.mensaje : 'No se pudo cargar el historial.', style: StreakText.secundario),
                const SizedBox(height: 8),
                BotonSecundario(
                  texto: 'Reintentar',
                  icono: StreakIcons.retry,
                  onPressed: () => ref.invalidate(pagosProProvider),
                ),
              ],
            ),
            data: (lista) => lista.isEmpty
                ? Text('Aún no hay pagos registrados.', style: StreakText.secundario)
                : Column(children: [for (final p in lista) FilaPago(p)]),
          ),
          const SizedBox(height: 16),
          Text(textoComoCancelar, style: StreakText.pequeno),
          EnlaceTexto(
            texto: textoEnlaceCondiciones,
            subrayado: true,
            onPressed: () => mostrarCondicionesPro(context, estado),
          ),
        ],
      ),
    );
  }
}

class FilaPago extends StatelessWidget {
  const FilaPago(this.pago, {super.key});

  final PagoPro pago;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaStreak(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\$${pago.monto} ${pago.moneda}', style: StreakText.tituloTarjeta),
                  const SizedBox(height: 2),
                  Text(DateFormat("d MMM yyyy · HH:mm", 'es').format(pago.fecha.toLocal()),
                      style: StreakText.pequeno),
                ],
              ),
            ),
            ChipStreak(
              nombreEstadoPago(pago.estado),
              variante: pago.estado == 'COMPLETADO' ? VarianteChip.pro : VarianteChip.neutro,
            ),
          ],
        ),
      ),
    );
  }
}

String nombreEstadoPago(String e) => switch (e) {
      'COMPLETADO' => 'Completado',
      'PENDIENTE' => 'Pendiente',
      'FALLIDO' => 'Fallido',
      'CANCELADO' => 'Cancelado',
      'REEMBOLSADO' => 'Reembolsado',
      _ => e,
    };
