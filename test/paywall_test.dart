import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/presentation/paywall_contenido.dart';

Future<void> _montar(WidgetTester tester, {EstadoPago estado = EstadoPago.inactivo, String? motivo}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PaywallContenido(estado: estado, motivoNoDisponible: motivo, onPagar: () {}, onVerificar: () {}),
    ),
  ));
}

void main() {
  testWidgets('RN-65: precio, periodo y cómo cancelar se ven ANTES del botón de pagar', (tester) async {
    await _montar(tester);
    final precio = tester.getTopLeft(find.byKey(const ValueKey('precio'))).dy;
    final periodo = tester.getTopLeft(find.byKey(const ValueKey('periodo'))).dy;
    final cancelar = tester.getTopLeft(find.byKey(const ValueKey('cancelar'))).dy;
    final boton = tester.getTopLeft(find.byKey(const ValueKey('boton-pagar'))).dy;
    expect(precio, lessThan(boton));
    expect(periodo, lessThan(boton));
    expect(cancelar, lessThan(boton));

    expect(find.text('USD 5.00'), findsOneWidget);
    expect(find.text('Pago único · sin renovación automática'), findsOneWidget);
    expect(find.textContaining('no hay suscripción que cancelar'), findsOneWidget);
    expect(find.textContaining('reembolsos escribe a soporte'), findsOneWidget);
  });

  testWidgets('declara explícitamente que PRO no da ventaja competitiva (RN-61/62)', (tester) async {
    await _montar(tester);
    expect(find.text(textoSinVentaja), findsOneWidget);
    expect(find.textContaining('no ves pronósticos ajenos antes del inicio'), findsOneWidget);
    expect(find.textContaining('ni sumas puntos extra'), findsOneWidget);
    // Ningún beneficio promete puntos ni ver pronósticos.
    for (final b in beneficiosPro) {
      expect(b.toLowerCase(), isNot(contains('puntos extra')));
      expect(b.toLowerCase(), isNot(contains('ver pronósticos')));
    }
  });

  testWidgets('lista solo beneficios que existen: 100 participantes, estadísticas y badge', (tester) async {
    await _montar(tester);
    expect(find.textContaining('hasta 100 participantes'), findsOneWidget);
    expect(find.textContaining('Estadísticas avanzadas'), findsOneWidget);
    expect(find.textContaining('Badge dorado'), findsOneWidget);
  });

  testWidgets('sin clave de Stripe el botón queda deshabilitado con el motivo a la vista', (tester) async {
    await _montar(tester, motivo: 'Los pagos aún no están configurados (falta STRIPE_PUBLISHABLE_KEY).');
    final boton = tester.widget<ElevatedButton>(find.byKey(const ValueKey('boton-pagar')));
    expect(boton.onPressed, isNull);
    expect(find.textContaining('STRIPE_PUBLISHABLE_KEY'), findsOneWidget);
  });

  testWidgets('con pagos disponibles el botón está activo', (tester) async {
    await _montar(tester);
    final boton = tester.widget<ElevatedButton>(find.byKey(const ValueKey('boton-pagar')));
    expect(boton.onPressed, isNotNull);
    expect(find.text('PAGAR USD 5.00'), findsOneWidget);
  });

  testWidgets('procesando: botón deshabilitado', (tester) async {
    await _montar(tester, estado: const EstadoPago(FasePago.procesando));
    final boton = tester.widget<ElevatedButton>(find.byKey(const ValueKey('boton-pagar')));
    expect(boton.onPressed, isNull);
  });

  testWidgets('tiempo agotado: "Pago recibido, activando PRO…" y botón para reintentar', (tester) async {
    await _montar(tester, estado: const EstadoPago(FasePago.pendienteActivacion, 'Pago recibido, activando PRO…'));
    expect(find.text('Pago recibido, activando PRO…'), findsOneWidget);
    expect(find.text('COMPROBAR DE NUEVO'), findsOneWidget);
    expect(find.byKey(const ValueKey('boton-pagar')), findsNothing);
  });

  testWidgets('error del backend se muestra', (tester) async {
    await _montar(tester, estado: const EstadoPago(FasePago.error, 'Los pagos no están disponibles por ahora.'));
    expect(find.byKey(const ValueKey('mensaje-pago')), findsOneWidget);
    expect(find.text('Los pagos no están disponibles por ahora.'), findsOneWidget);
  });
}
