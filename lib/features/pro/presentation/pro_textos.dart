import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/streak_theme.dart';
import '../../../core/widgets/botones.dart';
import '../../../core/widgets/estructura.dart';
import '../../../core/widgets/streak_icon.dart';
import '../data/pro_repository.dart';

const textoPagoUnico = 'Pago único · sin renovación automática';
const textoComoCancelar = 'No hay suscripción que cancelar. Para pedir un reembolso, escribe a soporte.';
const textoStripe = 'El pago lo procesa Stripe. STREAK no guarda los datos de tu tarjeta.';
const textoSinVentaja =
    'PRO no da ventaja en el juego: no ves pronósticos ajenos antes del inicio ni sumas puntos extra.';
const textoEnlaceCondiciones = 'Precio, periodo de cobro y cómo cancelar';

/// Beneficios REALES del plan (RN-61/62). Sin "Sin anuncios": la app no tiene anuncios.
List<String> beneficiosPro(EstadoPro e) => [
      'Hasta ${e.maxParticipantes} participantes por quiniela',
      'Insignia dorada en la tabla',
      'Estadísticas de cada quiniela: efectividad, racha y comparativa',
    ];

/// Lista con check amarillo (pantallas 22 y "Tu plan PRO").
class ListaBeneficios extends StatelessWidget {
  const ListaBeneficios({super.key, required this.estado});

  final EstadoPro estado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in beneficiosPro(estado))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StreakIcon(StreakIcons.check, color: StreakColors.accent, size: StreakSize.icon),
                const SizedBox(width: 16),
                Expanded(child: Text(b, style: StreakText.cuerpo)),
              ],
            ),
          ),
      ],
    );
  }
}

/// RN-65: hoja con el precio, el periodo de cobro y cómo cancelar, con texto real del plan.
Future<void> mostrarCondicionesPro(BuildContext context, EstadoPro e) {
  return mostrarHoja<void>(
    context,
    titulo: textoEnlaceCondiciones,
    contenido: (ctx) => [
      _Condicion(
        titulo: 'Precio',
        texto: '${e.importeConMoneda}, cobrado una sola vez al confirmar el pago.',
      ),
      const _Condicion(
        titulo: 'Periodo de cobro',
        texto: 'No hay periodo: es un pago único, sin renovación automática ni cargos posteriores.',
      ),
      const _Condicion(
        titulo: 'Cómo cancelar',
        texto: 'No hay suscripción que cancelar. Si quieres un reembolso, escribe a '
            '${AppConstants.correoSoporte} desde el correo de tu cuenta. Una compra que quedó a medias '
            '(sin cobrar) se puede cancelar desde la pantalla de pago.',
      ),
      if (e.modoPrueba)
        const _Condicion(
          titulo: 'Modo de prueba',
          texto: 'Los pagos están en modo de prueba de Stripe: no se hace ningún cobro real.',
        ),
      const _Condicion(titulo: 'Juego limpio', texto: textoSinVentaja),
      const SizedBox(height: 8),
      BotonSecundario(texto: 'Entendido', onPressed: () => Navigator.pop(ctx)),
    ],
  );
}

class _Condicion extends StatelessWidget {
  const _Condicion({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: StreakText.tituloTarjeta),
          const SizedBox(height: 4),
          Text(texto, style: StreakText.secundario),
        ],
      ),
    );
  }
}
