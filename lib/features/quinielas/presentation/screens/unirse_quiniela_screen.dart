import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/quinielas_controller.dart';
import '../../data/mock_catalog.dart';

class UnirseQuinielaScreen extends ConsumerStatefulWidget {
  const UnirseQuinielaScreen({super.key});

  @override
  ConsumerState<UnirseQuinielaScreen> createState() => _UnirseQuinielaScreenState();
}

class _UnirseQuinielaScreenState extends ConsumerState<UnirseQuinielaScreen> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final code = _codigo.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código tiene 6 caracteres')),
      );
      return;
    }

    final torneoEmpezado = MockCatalog.activos.any((t) => t.empezado);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Unirte a esta quiniela?'),
        content: Text(
          torneoEmpezado
              ? 'El torneo ya empezó. Solo pronosticarás partidos aún PROGRAMADOS. Los ya jugados te cuentan 0. ¿Confirmas? (RN-31)'
              : 'Vas a unirte con el código $code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    ref.read(quinielasControllerProvider.notifier).unirse(code);
    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Te uniste con el código $code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse con código')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Pide el código de 6 caracteres al administrador de la quiniela.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Código',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _unirse, child: const Text('UNIRME')),
          ],
        ),
      ),
    );
  }
}
