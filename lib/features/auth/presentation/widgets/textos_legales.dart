import 'package:flutter/material.dart';

import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/estructura.dart';

// Resúmenes que describen lo que la app hace de verdad (resumen de la política de privacidad del equipo).
// TODO(publicacion): enlazar también la URL pública de la política de privacidad cuando el equipo la publique; hoy no existe una URL real y no se inventa.

const _terminos = [
  'STREAK es un juego de quinielas de fútbol por puntos entre amigos. No se juega dinero entre participantes.',
  'Pronosticas el marcador de cada partido hasta 5 minutos antes de que empiece. '
      'Los puntos los calcula el servidor: 5 marcador exacto, 4 resultado y diferencia, 3 solo resultado, 0 fallo.',
  'El Plan Pro es un pago único opcional que no da ventaja en la tabla.',
  'Puedes eliminar tu cuenta cuando quieras desde la app.',
];

const _privacidad = [
  'Guardamos tu usuario, correo, contraseña cifrada y, si los das, nombre, apellidos, teléfono y foto.',
  'Los miembros de tus quinielas ven tu usuario, tu foto, tus puntos y, desde que empieza cada partido, tus pronósticos. '
      'Nunca mostramos tu correo ni tu teléfono a otras personas.',
  'Los pagos los procesa Stripe: los datos de tu tarjeta no pasan por STREAK.',
  'No vendemos tus datos ni mostramos publicidad.',
];

Future<void> _hoja(BuildContext context, String titulo, List<String> puntos) => mostrarHoja<void>(
      context,
      titulo: titulo,
      contenido: (ctx) => [
        for (final p in puntos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(p, style: StreakText.secundario),
          ),
        const SizedBox(height: 8),
        BotonSecundario(texto: 'Cerrar', onPressed: () => Navigator.pop(ctx)),
      ],
    );

Future<void> mostrarTerminos(BuildContext context) => _hoja(context, 'Términos de uso', _terminos);

Future<void> mostrarPrivacidad(BuildContext context) => _hoja(context, 'Política de privacidad', _privacidad);
