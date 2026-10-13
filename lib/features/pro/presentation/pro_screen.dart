import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/streak_theme.dart';
import '../../../core/widgets/icono_pro.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pago_pro_controller.dart';
import '../data/pro_repository.dart';
import 'paywall_contenido.dart';

/// Plan Pro: paywall para quien no lo tiene, "Tu plan PRO" con historial para quien sí.
class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esPro = ref.watch(authControllerProvider.select((s) => s.user?.esPro ?? false));
    final estado = ref.watch(pagoProControllerProvider);
    final ctrl = ref.read(pagoProControllerProvider.notifier);
    // Tras activarse en esta sesión se muestra "Tu plan PRO" (esPro ya es true).
    return Scaffold(
      appBar: AppBar(title: Text(esPro ? 'Tu plan PRO' : 'Hazte PRO')),
      body: esPro
          ? _TuPlanPro(recienActivado: estado.fase == FasePago.activo)
          : PaywallContenido(
              estado: estado,
              motivoNoDisponible: motivoPagosNoDisponibles(),
              onPagar: ctrl.pagar,
              onVerificar: ctrl.verificar,
            ),
    );
  }
}

class _TuPlanPro extends ConsumerWidget {
  const _TuPlanPro({required this.recienActivado});

  final bool recienActivado;

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
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: IconoPro(radio: 40)),
          const SizedBox(height: 8),
          Text(recienActivado ? '¡PRO activado!' : 'Tu plan PRO está activo',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: StreakColors.cream)),
          const SizedBox(height: 8),
          const Text(textoPagoUnico, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          for (final b in beneficiosPro)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.check_circle, color: StreakColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(b)),
              ]),
            ),
          const SizedBox(height: 8),
          const Text(textoSinVentaja, style: TextStyle(color: StreakColors.text, fontSize: 13)),
          const SizedBox(height: 24),
          Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          pagos.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Column(children: [
              Text(e is AppException ? e.mensaje : 'No se pudo cargar el historial.'),
              TextButton(onPressed: () => ref.invalidate(pagosProProvider), child: const Text('Reintentar')),
            ]),
            data: (lista) => lista.isEmpty
                ? const Text('Aún no hay pagos registrados.', style: TextStyle(color: StreakColors.text))
                : Column(children: [for (final p in lista) _FilaPago(p)]),
          ),
          const SizedBox(height: 16),
          const Text(textoComoCancelar, style: TextStyle(color: StreakColors.text, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago(this.pago);

  final PagoPro pago;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${pago.moneda} ${pago.monto}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(DateFormat("d MMM yyyy · HH:mm", 'es').format(pago.fecha.toLocal())),
        trailing: Text(_estado(pago.estado), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  static String _estado(String e) => switch (e) {
        'COMPLETADO' => 'Completado',
        'PENDIENTE' => 'Pendiente',
        'FALLIDO' => 'Fallido',
        'CANCELADO' => 'Cancelado',
        'REEMBOLSADO' => 'Reembolsado',
        _ => e,
      };
}
