import 'package:flutter/material.dart';

import '../theme/streak_theme.dart';
import 'streak_icon.dart';

/// Insignia PRO: corona amarilla sobre círculo `surface2` con borde amarillo.
class IconoPro extends StatelessWidget {
  const IconoPro({super.key, this.radio = 20, this.icono = StreakIcons.crownPro});

  final double radio;
  final StreakIcons icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radio * 2,
      height: radio * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StreakColors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: StreakColors.accent),
      ),
      child: StreakIcon(icono, color: StreakColors.accent, size: radio * 1.1),
    );
  }
}
