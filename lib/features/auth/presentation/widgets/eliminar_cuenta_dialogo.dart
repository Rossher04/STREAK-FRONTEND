import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/estructura.dart';
import '../../application/auth_controller.dart';

/// Punto de entrada único de "Eliminar cuenta" (panel lateral y perfil).
///
/// Versión de la fase 0: conserva el comportamiento anterior (solicitud por correo a soporte).
/// La fase 7 (pantalla 11) la sustituye por la confirmación con contraseña y `DELETE /usuarios/me/`,
/// que el backend ya ofrece (commit 91ebd2a).
Future<void> mostrarEliminarCuenta(BuildContext context) {
  final email = ProviderScope.containerOf(context, listen: false).read(authControllerProvider).user?.email ?? '';
  return mostrarDialogo<void>(
    context,
    titulo: 'Eliminar mi cuenta',
    texto: 'Por ahora la eliminación de la cuenta se solicita por correo a ${AppConstants.correoSoporte}, '
        'escribiendo desde el correo de tu cuenta${email.isEmpty ? '' : ' ($email)'}.\n\n'
        'Se borrarán tu perfil, tu foto y tus pronósticos.',
    contenido: (ctx) => [
      BotonSecundario(
        texto: 'Copiar correo',
        onPressed: () async {
          await Clipboard.setData(const ClipboardData(text: AppConstants.correoSoporte));
          if (ctx.mounted) avisar(ctx, 'Correo copiado');
        },
      ),
      const SizedBox(height: 12),
      BotonSecundario(texto: 'Cerrar', onPressed: () => Navigator.pop(ctx)),
    ],
  );
}
