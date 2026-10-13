import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/streak_theme.dart';

/// Íconos de trazo del paquete de diseño (`assets/icons/*.svg`, 24×24, trazo 1.8, color heredado).
/// Son provisionales: el equipo entregará los definitivos con el MISMO nombre de archivo, así que basta con
/// reemplazar el SVG sin tocar código.
enum StreakIcons {
  add,
  alert,
  back,
  ball,
  calendar,
  camera,
  card,
  check,
  chevronDown('chevron_down'),
  chevronRight('chevron_right'),
  close,
  copy,
  crownPro('crown_pro'),
  delete,
  eye,
  eyeOff('eye_off'),
  history,
  home,
  info,
  joinKey('join_key'),
  lock,
  logout,
  mail,
  menu,
  participants,
  pause,
  phone,
  retry,
  share,
  timer,
  trophy,
  user;

  const StreakIcons([this._archivo]);

  final String? _archivo;

  String get ruta => 'assets/icons/${_archivo ?? name}.svg';
}

/// Ícono SVG coloreado con [color] (por defecto, el del [IconTheme] actual).
class StreakIcon extends StatelessWidget {
  const StreakIcon(this.icono, {super.key, this.size, this.color, this.semanticLabel});

  final StreakIcons icono;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final lado = size ?? tema.size ?? StreakSize.icon;
    final c = color ?? tema.color ?? StreakColors.muted;
    final svg = SvgPicture.asset(
      icono.ruta,
      width: lado,
      height: lado,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      excludeFromSemantics: semanticLabel == null,
      semanticsLabel: semanticLabel,
    );
    return SizedBox(width: lado, height: lado, child: svg);
  }
}
