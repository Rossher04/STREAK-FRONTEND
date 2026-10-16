import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/streak_theme.dart';

/// Longitud del código de quiniela.
const largoCodigo = 6;

/// Caracteres admitidos al escribir un código (RN-27): mayúsculas y dígitos sin 0, O, 1, I ni L.
/// El backend ya no genera el 1 (serializers.py: `ABCDEFGHJKMNPQRSTUVWXYZ23456789`).
final codigoPermitido = RegExp('[A-HJKMNP-Z2-9]');

/// Pasa a mayúsculas, descarta lo que no admite el alfabeto y limita a 6 caracteres.
class CodigoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var limpio = newValue.text.toUpperCase().split('').where(codigoPermitido.hasMatch).join();
    if (limpio.length > largoCodigo) limpio = limpio.substring(0, largoCodigo);
    return TextEditingValue(text: limpio, selection: TextSelection.collapsed(offset: limpio.length));
  }
}

/// Seis casillas para el código. Debajo hay un único campo de texto invisible que recibe el teclado
/// (pegar, borrar y lectores de pantalla funcionan como en un campo normal).
class CasillasCodigo extends StatefulWidget {
  const CasillasCodigo({
    super.key,
    required this.controller,
    this.focusNode,
    this.conError = false,
    this.habilitado = true,
    this.onCompleto,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool conError;
  final bool habilitado;
  final VoidCallback? onCompleto;

  @override
  State<CasillasCodigo> createState() => _CasillasCodigoState();
}

class _CasillasCodigoState extends State<CasillasCodigo> {
  late final FocusNode _foco = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_cambio);
    _foco.addListener(_cambio);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_cambio);
    _foco.removeListener(_cambio);
    if (widget.focusNode == null) _foco.dispose();
    super.dispose();
  }

  void _cambio() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final texto = widget.controller.text;
    return SizedBox(
      height: StreakSize.cajaCodigoAlto,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Código de la quiniela, $largoCodigo caracteres',
              child: TextField(
                key: const Key('unirse.codigo'),
                controller: widget.controller,
                focusNode: _foco,
                enabled: widget.habilitado,
                autofocus: true,
                showCursor: false,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [CodigoFormatter()],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (v) {
                  if (v.length == largoCodigo) widget.onCompleto?.call();
                },
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < largoCodigo; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _casilla(i, texto)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _casilla(int i, String texto) {
    final activa = _foco.hasFocus && (i == texto.length || (texto.length == largoCodigo && i == largoCodigo - 1));
    final borde = widget.conError
        ? StreakColors.orangeText
        : activa
            ? StreakColors.cream
            : StreakColors.line;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StreakColors.surface1,
        borderRadius: StreakRadius.campo,
        border: Border.all(color: borde),
      ),
      child: Text(i < texto.length ? texto[i] : '', style: StreakText.cajaCodigo),
    );
  }
}
