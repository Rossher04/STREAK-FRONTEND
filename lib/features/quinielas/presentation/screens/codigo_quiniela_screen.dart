import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../application/quinielas_providers.dart';

/// Texto que se comparte: sobrio, solo el código.
String textoCompartirCodigo(String codigo) => 'Únete a mi quiniela en STREAK con el código $codigo';

/// Pantalla 13 · Código creado: código de 6 caracteres, Compartir (primario) y Copiar.
class CodigoQuinielaScreen extends ConsumerWidget {
  const CodigoQuinielaScreen({super.key, required this.quinielaId, this.compartir});

  final int quinielaId;

  /// Para pruebas: sustituye a la hoja de compartir del sistema.
  final Future<void> Function(String texto)? compartir;

  void _volver(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiniela = ref.watch(quinielaProvider(quinielaId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => _volver(context),
          icon: const StreakIcon(StreakIcons.back, color: StreakColors.text),
        ),
        title: const Text('Quiniela creada'),
      ),
      body: SafeArea(
        child: quiniela.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(StreakSize.screenPadding),
            child: EsqueletoTarjetas(cantidad: 1, alto: 150),
          ),
          error: (e, _) => EstadoError(
            mensaje: e is AppException ? e.mensaje : 'No se pudo cargar la quiniela.',
            sinConexion: e is AppException && e.codigo == 'NETWORK_ERROR',
            onReintentar: () => ref.invalidate(quinielaProvider(quinielaId)),
          ),
          data: (q) {
            final codigo = q.codigoUnico;
            // Los códigos nuevos no llevan 0, O, 1, I ni L (RN-27); los antiguos pueden llevar el 1.
            final sinAmbiguos = !RegExp('[0O1IL]').hasMatch(codigo);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  StreakSize.screenPadding, 16, StreakSize.screenPadding, StreakSize.screenPadding),
              children: [
                Text.rich(
                  TextSpan(
                    style: StreakText.secundario.copyWith(fontSize: StreakText.cuerpo.fontSize),
                    children: [
                      const TextSpan(text: 'Comparte este código para que otros se unan a '),
                      TextSpan(
                        text: q.nombre,
                        style: const TextStyle(color: StreakColors.text, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TarjetaStreak(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    children: [
                      const ChipStreak('CÓDIGO DE QUINIELA'),
                      const SizedBox(height: 10),
                      Semantics(
                        label: 'Código ${codigo.split('').join(' ')}',
                        excludeSemantics: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SelectableText(codigo, key: const Key('codigo.valor'), style: StreakText.codigo),
                        ),
                      ),
                      if (sinAmbiguos) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sin 0, O, 1, I ni L para dictarlo sin confusión',
                          textAlign: TextAlign.center,
                          style: StreakText.pequeno,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                BotonPrimario(
                  texto: 'Compartir código',
                  icono: StreakIcons.share,
                  onPressed: () {
                    final texto = textoCompartirCodigo(codigo);
                    (compartir ?? (t) => Share.share(t))(texto);
                  },
                ),
                const SizedBox(height: 12),
                BotonSecundario(
                  texto: 'Copiar código',
                  icono: StreakIcons.copy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: codigo));
                    if (context.mounted) avisar(context, 'Código $codigo copiado');
                  },
                ),
                const SizedBox(height: 8),
                EnlaceTexto(
                  texto: 'Ir a la quiniela',
                  onPressed: () => context.go('/quinielas/${q.id}'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
