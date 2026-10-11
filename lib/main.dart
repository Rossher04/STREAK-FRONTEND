import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/validacion_release.dart';
import 'core/constants/api_constants.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Segunda red tras el chequeo de Gradle: un release con marcadores de desarrollo no debe arrancar.
  if (kReleaseMode) {
    final problemas = problemasDeConfiguracion(
      correoSoporte: AppConstants.correoSoporte,
      apiBaseUrl: ApiConstants.envBaseUrl,
    );
    if (problemas.isNotEmpty) {
      throw StateError('Configuración de release incompleta: ${problemas.join(' | ')}');
    }
  }
  await initializeDateFormatting('es');
  await Hive.initFlutter();
  // PaymentSheet solo existe en Android e iOS; sin clave publicable el pago queda deshabilitado.
  if (AppConstants.stripePublishableKey.isNotEmpty && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    Stripe.publishableKey = AppConstants.stripePublishableKey;
  }

  runApp(
    const ProviderScope(
      child: StreakApp(),
    ),
  );
}

class StreakApp extends ConsumerWidget {
  const StreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'GT'), // Guatemala (RN-70)
        Locale('es', ''),
        Locale('en', ''),
      ],
    );
  }
}
