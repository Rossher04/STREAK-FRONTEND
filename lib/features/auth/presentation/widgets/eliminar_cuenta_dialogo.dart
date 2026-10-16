import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/eliminar_cuenta_screen.dart';

/// Punto de entrada único de "Eliminar cuenta" (panel lateral y perfil).
///
/// Fase 7: abre la pantalla 11 (`/eliminar-cuenta`), que pide la contraseña, confirma dos veces y
/// llama a `DELETE /usuarios/me/`. Se conserva el nombre para no tocar a quienes la llaman.
Future<void> mostrarEliminarCuenta(BuildContext context) => context.push<void>(rutaEliminarCuenta);
