import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Nạp ảnh nền trong `assets/scene/` thành [ui.Image] cho Flame.
/// Không dùng `images.load` của Flame vì nó tự thêm prefix `assets/images/`.
Future<ui.Image> loadSceneImage(String name) async {
  final data = await rootBundle.load('assets/scene/$name.webp');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

/// Nạp 1 frame sprite trận đánh trong `assets/fight/`.
Future<ui.Image> loadFightFrame(String name) async {
  final data = await rootBundle.load('assets/fight/$name.png');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}
