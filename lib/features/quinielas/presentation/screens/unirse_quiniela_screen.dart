import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/quinielas_providers.dart';

/// Caracteres permitidos en el código: mayúsculas y dígitos sin 0, O, I, L (RN-27).
/// El `1` sí se admite porque el backend lo genera (serializers.py, alfabeto del código).
final codigoPermitido = RegExp('[A-HJKMNP-Z1-9]');

class CodigoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final limpio = newValue.text
        .toUpperCase()
        .split('')
        .where(codigoPermitido.hasMatch)
        .join();
    final offset = limpio.length < newValue.selection.baseOffset ? limpio.length : newValue.selection.baseOffset;
    return TextEditingValue(
      text: limpio,
      selection: TextSelection.collapsed(offset: offset < 0 ? limpio.length : offset),
    );
  }
}

class UnirseQuinielaScreen extends ConsumerStatefulWidget {
  const UnirseQuinielaScreen({super.key});

  @override
  ConsumerState<UnirseQuinielaScreen> createState() => _UnirseQuinielaScreenState();
}

class _UnirseQuinielaScreenState extends ConsumerState<UnirseQuinielaScreen> {
  final _codigo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = _codigo.text.trim().toUpperCase();
    if (code.length != 6) {
      messenger.showSnackBar(const SnackBar(content: Text('El código tiene 6 caracteres')));
      return;
    }

    // El backend no permite consultar una quiniela por código sin unirse, así que no se
    // sabe de antemano si su torneo ya empezó: el aviso de ingreso tardío (RN-31) se
    // muestra siempre, con redacción condicional.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Unirte a esta quiniela?'),
        content: Text(
          'Vas a unirte con el código $code.\n\n'
          'Si el torneo ya empezó, solo podrás pronosticar los partidos que sigan PROGRAMADOS; '
          'los ya jugados te contarán 0 puntos (RN-31).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRMAR')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await ref.read(quinielasRepositoryProvider).unirse(code);
      refrescarQuinielas(ref);
      if (!mounted) return;
      context.go('/home');
      messenger.showSnackBar(SnackBar(content: Text('Te uniste con el código $code')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensajeUnirse(e))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
              inputFormatters: [CodigoFormatter(), LengthLimitingTextInputFormatter(6)],
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Código', counterText: ''),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enviando ? null : _unirse,
              child: Text(_enviando ? 'UNIENDO…' : 'UNIRME'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensajes claros para los errores de negocio de POST /quinielas/unirse/.
String mensajeUnirse(AppException e) {
  switch (e.codigo) {
    case 'QUINIELA_LLENA':
      return 'Esta quiniela ya está llena.';
    case 'YA_PARTICIPA':
      return 'Ya eres participante de esta quiniela.';
    case 'NO_ENCONTRADO':
      return 'No existe ninguna quiniela con ese código.';
    case 'TORNEO_NO_ACTIVO':
      return 'El torneo de esta quiniela ya no admite nuevas inscripciones.';
    default:
      return e.mensaje;
  }
}
