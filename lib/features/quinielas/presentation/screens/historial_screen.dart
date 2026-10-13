import 'package:flutter/material.dart';

import '../../../../core/widgets/barra_inferior.dart';
import '../../../auth/presentation/widgets/panel_lateral.dart';
import 'home_screen.dart';

/// Historial (21): quinielas de torneos finalizados (solo lectura). Pantalla con barra inferior y panel lateral.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BotonPanelLateral(),
        leadingWidth: 64,
        title: const Text('Historial'),
      ),
      drawer: const PanelLateral(),
      body: const ListaQuinielas(historial: true),
      bottomNavigationBar: const BarraInferior(activo: DestinoBarra.historial),
    );
  }
}
