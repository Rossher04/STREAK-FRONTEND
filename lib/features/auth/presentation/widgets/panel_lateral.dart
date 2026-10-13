import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../pro/application/pago_pro_controller.dart';
import '../../application/auth_controller.dart';
import 'eliminar_cuenta_dialogo.dart';

/// Avatar de la esquina superior izquierda que abre el panel lateral.
class BotonPanelLateral extends ConsumerWidget {
  const BotonPanelLateral({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Semantics(
      button: true,
      label: 'Abrir menú',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Scaffold.of(context).openDrawer(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AvatarUsuario(nombre: user?.displayName ?? '', fotoUrl: user?.fotoUrl),
        ),
      ),
    );
  }
}

/// Panel lateral: cabecera (foto, nombre, usuario y plan), Mi perfil, Cambiar contraseña, Plan Pro (chip de
/// precio o "PRO") y al pie Eliminar cuenta (naranja) y Cerrar sesión. Cada opción en una sola línea.
class PanelLateral extends ConsumerWidget {
  const PanelLateral({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final esPro = user?.esPro ?? false;
    final estado = ref.watch(estadoProProvider).valueOrNull;

    void ir(String ruta) {
      Navigator.of(context).pop();
      context.push(ruta);
    }

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: StreakColors.line))),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: StreakColors.line))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarUsuario(
                      nombre: user?.displayName ?? '',
                      fotoUrl: user?.fotoUrl,
                      diametro: StreakSize.avatarPanel,
                    ),
                    const SizedBox(height: 12),
                    Text(user?.displayName ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: StreakText.tituloHoja),
                    const SizedBox(height: 2),
                    Text('@${user?.username ?? ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: StreakText.pequeno),
                    const SizedBox(height: 10),
                    esPro
                        ? const ChipStreak('Plan PRO', variante: VarianteChip.pro, icono: StreakIcons.crownPro)
                        : const ChipStreak('Plan gratuito'),
                  ],
                ),
              ),
              _Opcion(icono: StreakIcons.user, texto: 'Mi perfil', onTap: () => ir('/perfil')),
              _Opcion(icono: StreakIcons.lock, texto: 'Cambiar contraseña', onTap: () => ir('/cambiar-password')),
              _Opcion(
                icono: StreakIcons.crownPro,
                texto: 'Plan Pro',
                onTap: () => ir('/pro'),
                chip: esPro
                    ? const ChipStreak('PRO', variante: VarianteChip.pro)
                    : estado == null
                        ? null
                        : ChipStreak('${estado.importeCorto} ${estado.moneda}', variante: VarianteChip.pro),
              ),
              const Spacer(),
              const Divider(),
              _Opcion(
                icono: StreakIcons.delete,
                texto: 'Eliminar cuenta',
                peligro: true,
                onTap: () {
                  Navigator.of(context).pop();
                  mostrarEliminarCuenta(context);
                },
              ),
              _Opcion(
                icono: StreakIcons.logout,
                texto: 'Cerrar sesión',
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icono, required this.texto, required this.onTap, this.chip, this.peligro = false});

  final StreakIcons icono;
  final String texto;
  final VoidCallback onTap;
  final Widget? chip;
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final color = peligro ? StreakColors.orangeText : StreakColors.text;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              StreakIcon(icono, color: peligro ? StreakColors.orangeText : StreakColors.muted),
              const SizedBox(width: 16),
              Expanded(
                child: Text(texto,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: StreakText.cuerpo.copyWith(color: color)),
              ),
              if (chip != null) chip!,
            ],
          ),
        ),
      ),
    );
  }
}
