import 'package:flutter/material.dart';

import '../theme/streak_theme.dart';
import 'botones.dart';
import 'marca.dart';
import 'streak_icon.dart';

/// Control segmentado (Pendientes / Resultados / Tabla): la opción activa va en `surface2`.
class PestanasSegmentadas extends StatelessWidget {
  const PestanasSegmentadas({super.key, required this.opciones, required this.indice, required this.onCambio});

  final List<String> opciones;
  final int indice;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StreakColors.surface1,
        borderRadius: StreakRadius.campo,
        border: Border.all(color: StreakColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++)
            Expanded(
              child: Semantics(
                selected: i == indice,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(StreakRadius.pestana),
                  onTap: () => onCambio(i),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == indice ? StreakColors.surface2 : null,
                      borderRadius: BorderRadius.circular(StreakRadius.pestana),
                    ),
                    child: Text(
                      opciones[i],
                      style: StreakText.cuerpoMedio.copyWith(
                        color: i == indice ? StreakColors.text : StreakColors.muted,
                        fontWeight: i == indice ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta base: `surface1`, borde `line` (o `cream` si [resaltada]) y radio 16.
class TarjetaStreak extends StatelessWidget {
  const TarjetaStreak({
    super.key,
    required this.child,
    this.onTap,
    this.resaltada = false,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.radio = StreakRadius.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool resaltada;
  final EdgeInsets padding;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    return Material(
      color: StreakColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: forma,
        side: BorderSide(color: resaltada ? StreakColors.cream : StreakColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Encabezado de sección en mayúsculas ("MIS QUINIELAS").
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion(this.texto, {super.key, this.derecha});

  final String texto;
  final Widget? derecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(texto.toUpperCase(), style: StreakText.seccion))),
          if (derecha != null) derecha!,
        ],
      ),
    );
  }
}

/// Dato "PUESTO 2.º" / "PUNTOS 145".
class DatoCifra extends StatelessWidget {
  const DatoCifra({super.key, required this.etiqueta, required this.valor, this.puntos = false, this.valorKey});

  final String etiqueta;
  final String valor;
  final bool puntos;
  final Key? valorKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta.toUpperCase(), style: StreakText.mini),
        const SizedBox(height: 2),
        Text(valor, key: valorKey, style: puntos ? StreakText.cifraPuntos : StreakText.cifra),
      ],
    );
  }
}

/// Aviso con borde naranja (alertas, sin conexión, contraseña temporal).
class BannerAviso extends StatelessWidget {
  const BannerAviso({super.key, required this.texto, this.icono = StreakIcons.alert, this.neutro = false});

  final String texto;
  final StreakIcons icono;

  /// Variante informativa (borde `line`, sin naranja): p. ej. "Quiniela finalizada · solo lectura".
  final bool neutro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: neutro ? StreakColors.surface1 : StreakColors.orangeTint,
        borderRadius: StreakRadius.campo,
        border: Border.all(color: neutro ? StreakColors.line : StreakColors.orange),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreakIcon(icono, size: 20, color: neutro ? StreakColors.muted : StreakColors.orangeText),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: StreakText.cuerpoMedio)),
        ],
      ),
    );
  }
}

/// Estado vacío con la estela de marca, un título, un texto y hasta dos acciones.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.titulo, required this.texto, this.acciones = const []});

  final String titulo;
  final String texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EstelaIlustracion(),
        const SizedBox(height: 28),
        Text(titulo, textAlign: TextAlign.center, style: StreakText.tituloGrande),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(texto, textAlign: TextAlign.center, style: StreakText.secundario),
        ),
        const SizedBox(height: 24),
        for (final a in acciones) Padding(padding: const EdgeInsets.only(bottom: 12), child: a),
      ],
    );
  }
}

/// Error de carga o sin conexión: ícono sobrio, mensaje y botón secundario "Reintentar".
class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.mensaje, required this.onReintentar, this.sinConexion = false});

  final String mensaje;
  final VoidCallback onReintentar;
  final bool sinConexion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StreakSize.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreakIcon(sinConexion ? StreakIcons.retry : StreakIcons.alert,
                size: 40, color: sinConexion ? StreakColors.muted : StreakColors.orangeText),
            const SizedBox(height: 16),
            Text(sinConexion ? 'Sin conexión' : 'No se pudo cargar',
                textAlign: TextAlign.center, style: StreakText.tituloHoja),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: StreakText.secundario),
            const SizedBox(height: 20),
            BotonSecundario(texto: 'Reintentar', icono: StreakIcons.retry, onPressed: onReintentar),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto de carga: tarjetas en `surface1` (sin spinner a pantalla completa).
class EsqueletoTarjetas extends StatelessWidget {
  const EsqueletoTarjetas({super.key, this.cantidad = 3, this.alto = 124});

  final int cantidad;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Column(
        children: [
          for (var i = 0; i < cantidad; i++)
            Container(
              height: alto,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StreakColors.surface1,
                borderRadius: StreakRadius.tarjeta,
                border: Border.all(color: StreakColors.line),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Barra(ancho: 150),
                  SizedBox(height: 12),
                  _Barra(ancho: 210),
                  SizedBox(height: 16),
                  _Barra(ancho: 90),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.ancho});

  final double ancho;

  @override
  Widget build(BuildContext context) => Container(
        width: ancho,
        height: 12,
        decoration: BoxDecoration(color: StreakColors.surface2, borderRadius: StreakRadius.pildora),
      );
}

/// Hoja inferior con título, texto opcional y contenido. Devuelve lo que pase `Navigator.pop`.
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required String titulo,
  String? texto,
  required List<Widget> Function(BuildContext ctx) contenido,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            StreakSize.screenPadding, 22, StreakSize.screenPadding, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text(titulo, style: StreakText.tituloHoja)),
            if (texto != null) ...[
              const SizedBox(height: 8),
              Text(texto, style: StreakText.secundario),
            ],
            const SizedBox(height: 16),
            ...contenido(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Diálogo centrado sobre el velo oscuro.
Future<T?> mostrarDialogo<T>(
  BuildContext context, {
  required String titulo,
  String? texto,
  required List<Widget> Function(BuildContext ctx) contenido,
  bool descartable = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: descartable,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: StreakSize.screenPadding, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text(titulo, style: StreakText.tituloHoja)),
            if (texto != null) ...[
              const SizedBox(height: 8),
              Text(texto, style: StreakText.secundario),
            ],
            const SizedBox(height: 16),
            ...contenido(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Muestra un aviso breve abajo.
void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
