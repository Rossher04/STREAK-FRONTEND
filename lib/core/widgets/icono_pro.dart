import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Insignia dorada de PRO sobre fondo azul (el dorado solo, sobre blanco, tiene contraste 1.8:1).
class IconoPro extends StatelessWidget {
  const IconoPro({super.key, this.radio = 20, this.icono = Icons.workspace_premium});

  final double radio;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: AppColors.primaryBlue,
      child: Icon(icono, color: AppColors.goldAccent, size: radio * 1.2),
    );
  }
}
