import 'package:flutter/material.dart';

import '../theme.dart';

/// Chân dung trùm theo chương. Chương chưa có ảnh thì rơi về icon.
class BossAvatar extends StatelessWidget {
  const BossAvatar({
    super.key,
    required this.chapterId,
    this.size = 56,
    this.dimmed = false,
    this.borderColor = GH.line,
  });

  final int chapterId;
  final double size;

  /// Chương chưa mở: xám lại để không tranh mắt với chương đang đánh.
  final bool dimmed;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/char/boss_chuong${chapterId + 1}.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: GH.panel2,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.5, color: GH.muted),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: dimmed
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.35,
                0.35,
                0.35,
                0,
                0,
                0.35,
                0.35,
                0.35,
                0,
                0,
                0.35,
                0.35,
                0.35,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: image,
            )
          : image,
    );
  }
}
