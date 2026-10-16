import 'package:flutter/material.dart';

import 'streak_colors.dart';

export 'streak_colors.dart';

/// Radios (design/tokens.json → radius). `pestana` y `fila` salen de la maqueta (streak.css).
abstract final class StreakRadius {
  static const field = 12.0;
  static const button = 12.0;
  static const card = 16.0;
  static const sheet = 22.0;
  static const chip = 999.0;

  /// Fila de la tabla y de pronósticos (`.trow`).
  static const fila = 14.0;

  /// Pestaña activa dentro del control segmentado (`.tabs span`).
  static const pestana = 9.0;

  static BorderRadius get campo => BorderRadius.circular(field);
  static BorderRadius get tarjeta => BorderRadius.circular(card);
  static BorderRadius get filaTabla => BorderRadius.circular(fila);
  static BorderRadius get pildora => BorderRadius.circular(chip);
}

/// Medidas (design/tokens.json → size, y las de componentes de la maqueta).
abstract final class StreakSize {
  static const fieldHeight = 50.0;
  static const buttonHeight = 52.0;
  static const bottomNavHeight = 76.0;
  static const screenPadding = 20.0;
  static const icon = 24.0;
  static const iconSmall = 18.0;
  static const iconChip = 16.0;
  static const iconMini = 14.0;
  static const iconStroke = 1.8;
  static const appBar = 56.0;

  static const avatar = 36.0;
  static const avatarPanel = 56.0;
  static const avatarGrande = 64.0;
  static const fotoPerfil = 92.0;
  static const escudo = 40.0;
  static const cajaGolesAncho = 46.0;
  static const cajaGolesAlto = 50.0;
  static const cajaCodigoAlto = 56.0;
  static const panelLateral = 318.0;
  static const indicadorBarra = 22.0;
  static const botonCrearAncho = 44.0;
  static const botonCrearAlto = 30.0;
  static const puntoEstado = 6.0;
  static const casilla = 20.0;
}

/// Estilos de texto. Sora: títulos, cifras y botones. Inter: texto y formularios.
abstract final class StreakText {
  static const display = 'Sora';
  static const body = 'Inter';

  static const _sora = TextStyle(fontFamily: display, color: StreakColors.text);
  static const _inter = TextStyle(fontFamily: body, color: StreakColors.text);

  // Marca
  static final wordmark = _sora.copyWith(
      fontSize: 34, fontWeight: FontWeight.w700, color: StreakColors.cream, letterSpacing: 2);
  static final wordmarkBarra = _sora.copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4);
  static final lema = _inter.copyWith(
      fontSize: 11, fontWeight: FontWeight.w500, color: StreakColors.muted, letterSpacing: 2.2);

  // Títulos (Sora)
  static final titulo = _sora.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static final tituloHoja = _sora.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final tituloGrande = _sora.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static final tituloTarjeta = _sora.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static final boton = _sora.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  // Cifras (Sora)
  static final cifra = _sora.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: StreakColors.cream);
  static final cifraPuntos = cifra.copyWith(color: StreakColors.accent);
  static final cifraFila = _sora.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
  static final posicion = _sora.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: StreakColors.muted);
  static final marcador = _sora.copyWith(
      fontSize: 28, fontWeight: FontWeight.w700, color: StreakColors.cream, letterSpacing: 1.1);
  static final marcadorFila = _sora.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: StreakColors.muted);
  static final cajaGoles = _sora.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final cajaCodigo = _sora.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: StreakColors.cream);
  static final codigo = _sora.copyWith(
      fontSize: 38, fontWeight: FontWeight.w700, color: StreakColors.cream, letterSpacing: 8.4);
  static final cifraGrande = _sora.copyWith(fontSize: 28, fontWeight: FontWeight.w700, color: StreakColors.cream);
  static final precio = _sora.copyWith(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1);
  static final precioResumen = _sora.copyWith(fontSize: 28, fontWeight: FontWeight.w700);

  // Texto (Inter)
  static final cuerpo = _inter.copyWith(fontSize: 15);
  static final cuerpoMedio = _inter.copyWith(fontSize: 14, height: 1.45);
  static final secundario = _inter.copyWith(fontSize: 14, height: 1.5, color: StreakColors.muted);
  static final pequeno = _inter.copyWith(fontSize: 13, height: 1.45, color: StreakColors.muted);
  static final etiqueta = _inter.copyWith(fontSize: 12, color: StreakColors.muted, letterSpacing: 0.24);
  static final mini = _inter.copyWith(fontSize: 11, color: StreakColors.muted);
  static final seccion = _inter.copyWith(fontSize: 13, color: StreakColors.muted, letterSpacing: 1.2);
  static final error = _inter.copyWith(fontSize: 12, color: StreakColors.orangeText, height: 1.4);
  static final enlace = _inter.copyWith(fontSize: 14, color: StreakColors.muted);

  /// Iniciales dentro de un círculo de [diametro] (avatar o escudo).
  static TextStyle iniciales(double diametro, {Color color = StreakColors.text}) =>
      _sora.copyWith(fontSize: diametro * 0.38, fontWeight: FontWeight.w700, color: color);

  static TextTheme get textTheme => TextTheme(
        displaySmall: cifraGrande,
        headlineSmall: tituloGrande,
        titleLarge: titulo,
        titleMedium: tituloTarjeta,
        titleSmall: cuerpo.copyWith(fontWeight: FontWeight.w600),
        labelLarge: boton,
        labelMedium: etiqueta,
        labelSmall: mini,
        bodyLarge: cuerpo,
        bodyMedium: cuerpoMedio,
        bodySmall: etiqueta,
      );
}

/// Tema oscuro único de STREAK (design/flutter/streak_theme.dart adaptado a Flutter 3.41).
abstract final class StreakTheme {
  static OutlineInputBorder _borde(Color c) => OutlineInputBorder(
        borderRadius: StreakRadius.campo,
        borderSide: BorderSide(color: c),
      );

  static ThemeData dark() {
    final scheme = const ColorScheme.dark().copyWith(
      primary: StreakColors.accent,
      onPrimary: StreakColors.accentInk,
      secondary: StreakColors.brand,
      onSecondary: StreakColors.text,
      surface: StreakColors.surface1,
      onSurface: StreakColors.text,
      onSurfaceVariant: StreakColors.muted,
      surfaceContainerHighest: StreakColors.surface2,
      error: StreakColors.orange,
      onError: StreakColors.text,
      outline: StreakColors.line,
      outlineVariant: StreakColors.line,
    );
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(StreakRadius.button));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: StreakText.body,
      scaffoldBackgroundColor: StreakColors.bg,
      canvasColor: StreakColors.surface1,
      dividerColor: StreakColors.line,
      dividerTheme: const DividerThemeData(color: StreakColors.line, thickness: 1, space: 1),
      textTheme: StreakText.textTheme,
      iconTheme: const IconThemeData(color: StreakColors.muted, size: StreakSize.icon),
      appBarTheme: AppBarTheme(
        backgroundColor: StreakColors.bg,
        foregroundColor: StreakColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        toolbarHeight: StreakSize.appBar,
        titleTextStyle: StreakText.titulo,
        iconTheme: const IconThemeData(color: StreakColors.text, size: StreakSize.icon),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StreakColors.surface1,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: StreakText.cuerpo.copyWith(color: StreakColors.hint),
        helperStyle: StreakText.etiqueta,
        errorStyle: StreakText.error,
        counterStyle: StreakText.mini,
        border: _borde(StreakColors.line),
        enabledBorder: _borde(StreakColors.line),
        focusedBorder: _borde(StreakColors.cream),
        errorBorder: _borde(StreakColors.orangeText),
        focusedErrorBorder: _borde(StreakColors.orangeText),
        disabledBorder: _borde(StreakColors.line),
        suffixIconColor: StreakColors.muted,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: StreakColors.cream,
        selectionColor: StreakColors.brand,
        selectionHandleColor: StreakColors.cream,
      ),
      // Botón primario (amarillo). Máximo uno por pantalla.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StreakColors.accent,
          foregroundColor: StreakColors.accentInk,
          disabledBackgroundColor: StreakColors.surface2,
          disabledForegroundColor: StreakColors.muted,
          minimumSize: const Size.fromHeight(StreakSize.buttonHeight),
          elevation: 0,
          textStyle: StreakText.boton,
          shape: forma,
        ),
      ),
      // Botón secundario (borde).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StreakColors.text,
          disabledForegroundColor: StreakColors.muted,
          minimumSize: const Size.fromHeight(StreakSize.buttonHeight),
          side: const BorderSide(color: StreakColors.line),
          textStyle: StreakText.boton,
          shape: forma,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: StreakColors.muted,
          textStyle: StreakText.enlace,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: StreakColors.text, minimumSize: const Size(48, 48)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: const WidgetStatePropertyAll(StreakColors.surface1),
        checkColor: const WidgetStatePropertyAll(StreakColors.accent),
        side: const BorderSide(color: StreakColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: StreakColors.brand,
        inactiveTrackColor: StreakColors.surface2,
        thumbColor: StreakColors.text,
        overlayColor: Colors.transparent,
        trackHeight: 6,
        valueIndicatorColor: StreakColors.surface2,
        showValueIndicator: ShowValueIndicator.never,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StreakColors.surface1,
        modalBackgroundColor: StreakColors.surface1,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: StreakColors.scrim,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(StreakRadius.sheet)),
          side: BorderSide(color: StreakColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: StreakColors.surface1,
        surfaceTintColor: Colors.transparent,
        barrierColor: StreakColors.scrim,
        titleTextStyle: StreakText.tituloHoja,
        contentTextStyle: StreakText.secundario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StreakRadius.sheet),
          side: const BorderSide(color: StreakColors.line),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: StreakColors.surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StreakRadius.sheet),
          side: const BorderSide(color: StreakColors.line),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: StreakColors.surface1,
        surfaceTintColor: Colors.transparent,
        scrimColor: StreakColors.scrim,
        width: StreakSize.panelLateral,
        shape: RoundedRectangleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: StreakColors.surface2,
        contentTextStyle: StreakText.cuerpoMedio,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StreakRadius.field),
          side: const BorderSide(color: StreakColors.line),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: StreakColors.accent),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: StreakText.cuerpo),
      popupMenuTheme: const PopupMenuThemeData(color: StreakColors.surface1),
    );
  }
}
