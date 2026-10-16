import 'package:flutter/material.dart';

import '../../../../core/utils/fecha_nacimiento.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/streak_icon.dart';

/// Campo "Fecha de nacimiento" (RN-09) de registro y perfil: se escribe como dd/mm/aaaa o se elige en el
/// selector de fecha (ícono de calendario). Es opcional. La pantalla lee el valor con [FechaNacimiento.parseVista].
class CampoFechaNacimiento extends StatelessWidget {
  const CampoFechaNacimiento({super.key, required this.controller, this.errorServidor, this.habilitado = true});

  final TextEditingController controller;
  final String? errorServidor;
  final bool habilitado;

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateTime.now();
    final actual = FechaNacimiento.parseVista(controller.text);
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime(hoy.year - 25, hoy.month, hoy.day),
      firstDate: FechaNacimiento.minima(hoy),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      helpText: 'Fecha de nacimiento',
      fieldLabelText: 'dd/mm/aaaa',
    );
    if (elegida != null) controller.text = FechaNacimiento.aVista(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      campoKey: const Key('fecha_nacimiento'),
      etiqueta: 'Fecha de nacimiento',
      hint: 'dd/mm/aaaa',
      controller: controller,
      habilitado: habilitado,
      keyboardType: TextInputType.number,
      inputFormatters: const [FormatoFechaVista()],
      sufijo: StreakIcons.calendar,
      sufijoTooltip: 'Elegir fecha de nacimiento',
      onSufijoTap: habilitado ? () => _elegir(context) : null,
      errorServidor: errorServidor,
      validator: FechaNacimiento.validar,
    );
  }
}
