import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/streak_theme.dart';
import 'streak_icon.dart';

/// Campo con la etiqueta ARRIBA (12 px), caja de 50 px y error = borde naranja + mensaje en `orangeText`
/// debajo + ícono de alerta. [errorServidor] muestra el error por campo que devuelve la API (RN-72).
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.controller,
    this.initialValue,
    this.hint,
    this.ayuda,
    this.errorServidor,
    this.validator,
    this.contrasena = false,
    this.soloLectura = false,
    this.habilitado = true,
    this.sufijo,
    this.sufijoTooltip,
    this.onSufijoTap,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.campoKey,
  });

  final String etiqueta;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;

  /// Texto de ayuda bajo el campo (p. ej. reglas de la contraseña).
  final String? ayuda;
  final String? errorServidor;
  final FormFieldValidator<String>? validator;

  /// Oculta el texto y agrega el ojo para mostrarlo.
  final bool contrasena;

  /// Solo lectura con candado (p. ej. el usuario, que no se puede cambiar).
  final bool soloLectura;
  final bool habilitado;
  final StreakIcons? sufijo;

  /// Si se da, el ícono [sufijo] es un botón (p. ej. el calendario de la fecha de nacimiento).
  final VoidCallback? onSufijoTap;
  final String? sufijoTooltip;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Key? campoKey;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;
  String? _errorValidacion;

  String? _validar(String? v) {
    final e = widget.validator?.call(v);
    if (e != _errorValidacion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _errorValidacion = e);
      });
    }
    return e;
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorServidor ?? _errorValidacion;
    final conError = error != null;
    Widget? sufijo;
    if (widget.contrasena) {
      sufijo = IconButton(
        tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: () => setState(() => _oculto = !_oculto),
        icon: StreakIcon(_oculto ? StreakIcons.eye : StreakIcons.eyeOff, color: StreakColors.muted),
      );
    } else if (widget.soloLectura) {
      sufijo = const Padding(
        padding: EdgeInsets.all(12),
        child: StreakIcon(StreakIcons.lock, color: StreakColors.muted),
      );
    } else if (conError) {
      sufijo = const Padding(
        padding: EdgeInsets.all(12),
        child: StreakIcon(StreakIcons.alert, color: StreakColors.orangeText),
      );
    } else if (widget.sufijo != null && widget.onSufijoTap != null) {
      sufijo = IconButton(
        tooltip: widget.sufijoTooltip,
        onPressed: widget.onSufijoTap,
        icon: StreakIcon(widget.sufijo!, color: StreakColors.muted),
      );
    } else if (widget.sufijo != null) {
      sufijo = Padding(
        padding: const EdgeInsets.all(12),
        child: StreakIcon(widget.sufijo!, color: StreakColors.muted),
      );
    }
    final habilitado = widget.habilitado && !widget.soloLectura;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Text(widget.etiqueta, style: StreakText.etiqueta)),
          const SizedBox(height: 6),
          Semantics(
            label: widget.etiqueta,
            child: TextFormField(
            key: widget.campoKey,
            controller: widget.controller,
            initialValue: widget.controller == null ? widget.initialValue : null,
            enabled: habilitado,
            obscureText: widget.contrasena && _oculto,
            obscuringCharacter: '•',
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            autocorrect: !widget.contrasena,
            enableSuggestions: !widget.contrasena,
            style: StreakText.cuerpo.copyWith(color: habilitado ? StreakColors.text : StreakColors.muted),
            validator: widget.validator == null ? null : _validar,
            forceErrorText: widget.errorServidor,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.ayuda,
              helperMaxLines: 3,
              errorMaxLines: 3,
              fillColor: widget.soloLectura ? StreakColors.bg : null,
              suffixIcon: sufijo,
            ),
          ),
          ),
        ],
    );
  }
}
