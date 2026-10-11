/// Reglas puras del Plan Pro: espera con backoff, clave de idempotencia y estadísticas.
library;

import 'dart:math';

import '../../quinielas/domain/quiniela_vista.dart';

/// Esperas sucesivas (backoff exponencial acotado) para consultar /pro/estado/ hasta que el
/// webhook de Stripe active PRO. La suma es exactamente [total].
List<Duration> planEspera({
  Duration total = const Duration(seconds: 30),
  Duration inicial = const Duration(seconds: 1),
  Duration maximo = const Duration(seconds: 6),
}) {
  final esperas = <Duration>[];
  var acumulado = Duration.zero;
  var siguiente = inicial;
  while (acumulado < total) {
    final resto = total - acumulado;
    final espera = siguiente < resto ? siguiente : resto;
    esperas.add(espera);
    acumulado += espera;
    siguiente = Duration(milliseconds: min(siguiente.inMilliseconds * 2, maximo.inMilliseconds));
  }
  return esperas;
}

/// Clave de idempotencia de 32 caracteres hexadecimales aleatorios (el backend acepta
/// 8 a 128 letras, números, guiones; views_payments.py).
String generarClaveIdempotencia([Random? azar]) {
  final r = azar ?? Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class EstadisticasPro {
  const EstadisticasPro({
    required this.resueltosConPronostico,
    required this.conPuntos,
    required this.exactos,
    required this.rachaActual,
    required this.mejorRacha,
    required this.misPuntos,
    required this.promedioTabla,
  });

  /// Partidos FINALIZADOS en los que pronostiqué.
  final int resueltosConPronostico;
  final int conPuntos;
  final int exactos;
  final int rachaActual;
  final int mejorRacha;
  final int misPuntos;

  /// Promedio de puntos_totales de todos los participantes (incluido yo); null sin tabla.
  final double? promedioTabla;

  /// Efectividad %: partidos con puntos / partidos resueltos con pronóstico; null sin datos.
  double? get efectividad =>
      resueltosConPronostico == 0 ? null : conPuntos * 100 / resueltosConPronostico;

  /// Mis puntos menos el promedio de la tabla; null sin tabla.
  double? get diferenciaConPromedio => promedioTabla == null ? null : misPuntos - promedioTabla!;
}

/// Estadísticas calculadas solo con datos que ya entrega la API (partidos con mi pronóstico y
/// tabla). Solo cuentan los partidos FINALIZADOS: SUSPENDIDO y CANCELADO no cuentan (RN-22).
/// La racha es de partidos consecutivos con puntos, del más reciente hacia atrás; un partido
/// finalizado sin pronóstico vale 0 y la rompe (el "no rompas la racha" de la marca).
EstadisticasPro calcularEstadisticas({
  required List<Partido> partidos,
  required List<FilaTabla> tabla,
  required int usuarioId,
}) {
  final finalizados = partidos.where((p) => p.estado == 'FINALIZADO').toList()
    ..sort((a, b) {
      final porFecha = a.fechaHora.compareTo(b.fechaHora);
      return porFecha != 0 ? porFecha : a.id.compareTo(b.id);
    });

  final conPronostico = finalizados.where((p) => p.pronostico != null).toList();
  final conPuntos = conPronostico.where((p) => p.puntos > 0).length;
  final exactos = conPronostico.where((p) => p.puntos == 5).length;

  var mejor = 0;
  var actual = 0;
  for (final p in finalizados) {
    if (p.pronostico != null && p.puntos > 0) {
      actual++;
      mejor = max(mejor, actual);
    } else {
      actual = 0;
    }
  }

  final mia = tabla.where((f) => f.usuarioId == usuarioId).firstOrNull;
  final promedio =
      tabla.isEmpty ? null : tabla.fold<int>(0, (s, f) => s + f.puntos) / tabla.length;

  return EstadisticasPro(
    resueltosConPronostico: conPronostico.length,
    conPuntos: conPuntos,
    exactos: exactos,
    rachaActual: actual,
    mejorRacha: mejor,
    misPuntos: mia?.puntos ?? 0,
    promedioTabla: promedio,
  );
}
