import 'package:flutter/material.dart';

import '../theme.dart';

/// Ảnh nền pixel cho từng khu vực, kèm lớp phủ tối để chữ/panel vẫn đọc được.
class SceneBg extends StatelessWidget {
  const SceneBg({
    super.key,
    required this.name,
    this.alignment = Alignment.topCenter,
    this.scrim = const [0.55, 0.45, 0.92],
  });

  /// Tên file trong `assets/scene/`, không gồm đuôi.
  final String name;
  final Alignment alignment;

  /// Độ tối lớp phủ ở 3 mốc: đỉnh, giữa, đáy.
  final List<double> scrim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/scene/$name.webp',
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                GH.bg.withValues(alpha: scrim[0]),
                GH.bg.withValues(alpha: scrim[1]),
                GH.bg.withValues(alpha: scrim[2]),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}
