import 'package:flutter/material.dart';

import '../theme/streak_theme.dart';
import 'streak_icon.dart';

/// Contenido común: texto con ícono opcional o indicador de carga.
class _ContenidoBoton extends StatelessWidget {
  const _ContenidoBoton({required this.texto, this.icono, this.cargando = false, required this.color});

  final String texto;
  final StreakIcons? icono;
  final bool cargando;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return SizedBox(
        width: StreakSize.iconSmall,
        height: StreakSize.iconSmall,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    final etiqueta = Text(texto, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis);
    if (icono == null) return etiqueta;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreakIcon(icono!, color: color, size: StreakSize.icon),
        const SizedBox(width: 10),
        Flexible(child: etiqueta),
      ],
    );
  }
}

/// Botón primario (amarillo). Regla: como máximo UNO relleno por pantalla.
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({super.key, required this.texto, this.onPressed, this.cargando = false, this.icono});

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final StreakIcons? icono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: cargando ? texto : null,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        child: _ContenidoBoton(
          texto: texto,
          icono: icono,
          cargando: cargando,
          color: onPressed == null || cargando ? StreakColors.muted : StreakColors.accentInk,
        ),
      ),
    );
  }
}

/// Botón secundario: borde `line` y texto `text`.
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.texto, this.onPressed, this.cargando = false, this.icono});

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final StreakIcons? icono;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: cargando ? null : onPressed,
      child: _ContenidoBoton(
        texto: texto,
        icono: icono,
        cargando: cargando,
        color: onPressed == null ? StreakColors.muted : StreakColors.text,
      ),
    );
  }
}

/// Botón destructivo: borde naranja y texto `orangeText` (nunca relleno).
class BotonDestructivo extends StatelessWidget {
  const BotonDestructivo({super.key, required this.texto, this.onPressed, this.cargando = false});

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: cargando ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: StreakColors.orangeText,
        side: const BorderSide(color: StreakColors.orangeText),
      ),
      child: _ContenidoBoton(texto: texto, cargando: cargando, color: StreakColors.orangeText),
    );
  }
}

/// Enlace de texto (p. ej. "¿Olvidaste tu contraseña?").
class EnlaceTexto extends StatelessWidget {
  const EnlaceTexto({super.key, required this.texto, required this.onPressed, this.subrayado = false});

  final String texto;
  final VoidCallback onPressed;
  final bool subrayado;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: StreakText.enlace.copyWith(
          decoration: subrayado ? TextDecoration.underline : null,
          decorationColor: StreakColors.muted,
        ),
      ),
    );
  }
}
