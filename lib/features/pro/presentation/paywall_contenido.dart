import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/streak_theme.dart';
import '../../../core/widgets/icono_pro.dart';
import '../application/pago_pro_controller.dart';

const textoPagoUnico = 'Pago único · sin renovación automática';
const textoComoCancelar =
    'Cómo cancelar: es un pago único, no hay suscripción que cancelar. '
    'Para reembolsos escribe a soporte.';
const textoSinVentaja =
    'PRO no da ventaja: no ves pronósticos ajenos antes del inicio ni sumas puntos extra.';

/// Beneficios de comodidad y estadística (RN-61/62). Solo se listan los que existen en la app.
const beneficiosPro = [
  'Quinielas de hasta 100 participantes (el plan gratis llega a 50)',
  'Estadísticas avanzadas de cada quiniela: efectividad, racha y comparativa',
  'Badge dorado en tu perfil',
];

/// Paywall (RN-65): precio, periodo, cómo cancelar y beneficios, TODO antes del botón de pagar.
class PaywallContenido extends StatelessWidget {
  const PaywallContenido({
    super.key,
    required this.estado,
    required this.motivoNoDisponible,
    required this.onPagar,
    required this.onVerificar,
  });

  final EstadoPago estado;

  /// Si no es null, el pago está deshabilitado y se muestra este motivo.
  final String? motivoNoDisponible;
  final VoidCallback onPagar;
  final VoidCallback onVerificar;

  @override
  Widget build(BuildContext context) {
    final ocupado = estado.fase == FasePago.procesando || estado.fase == FasePago.activando;
    final pendiente = estado.fase == FasePago.pendienteActivacion;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(child: IconoPro(radio: 36)),
        const SizedBox(height: 8),
        const Text('STREAK PRO',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: StreakColors.cream)),
        const SizedBox(height: 16),
        const Text('USD ${AppConstants.precioProUsd}',
            key: ValueKey('precio'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const Text(textoPagoUnico,
            key: ValueKey('periodo'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (final b in beneficiosPro)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: StreakColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(b)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StreakColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StreakColors.accent),
          ),
          child: const Text(textoSinVentaja, key: ValueKey('sin-ventaja')),
        ),
        const SizedBox(height: 12),
        const Text(textoComoCancelar,
            key: ValueKey('cancelar'), style: TextStyle(color: StreakColors.text, fontSize: 13)),
        const SizedBox(height: 20),
        if (motivoNoDisponible != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(motivoNoDisponible!,
                textAlign: TextAlign.center, style: const TextStyle(color: StreakColors.orangeText)),
          ),
        if (estado.mensaje != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              estado.mensaje!,
              key: const ValueKey('mensaje-pago'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: estado.fase == FasePago.error ? StreakColors.orangeText : StreakColors.cream,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (pendiente)
          ElevatedButton(onPressed: onVerificar, child: const Text('COMPROBAR DE NUEVO'))
        else
          ElevatedButton(
            key: const ValueKey('boton-pagar'),
            onPressed: (motivoNoDisponible != null || ocupado) ? null : onPagar,
            child: Text(switch (estado.fase) {
              FasePago.procesando => 'PROCESANDO…',
              FasePago.activando => 'ACTIVANDO PRO…',
              _ => 'PAGAR USD ${AppConstants.precioProUsd}',
            }),
          ),
        const SizedBox(height: 8),
        const Text(
          'El pago lo procesa Stripe: los datos de tu tarjeta nunca pasan por STREAK.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StreakColors.text, fontSize: 12),
        ),
      ],
    );
  }
}
