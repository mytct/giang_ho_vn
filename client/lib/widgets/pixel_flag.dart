import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/paint_utils.dart';
import '../theme.dart';

const Map<String, Color> _npcGangColors = {
  'npc:ran': Color(0xFF1FA96B),
  'npc:ca': Color(0xFF00A89E),
  'npc:o': Color(0xFF6A3AD9),
  'npc:chuot': Color(0xFFB58A5A),
};

const List<Color> _gangPalette = [
  Color(0xFFFF5252),
  Color(0xFF00E5D0),
  Color(0xFF3EE08F),
  Color(0xFFFFC93C),
  Color(0xFF9B6BFF),
  Color(0xFFFF7A00),
  Color(0xFF4DA3FF),
  Color(0xFFB7FF3C),
  Color(0xFFFF6BD6),
  Color(0xFF2EE6A8),
  Color(0xFFFFA8C5),
  Color(0xFF7C9CFF),
  Color(0xFFE0C568),
  Color(0xFF66E7FF),
  Color(0xFFC978FF),
  Color(0xFF9DFF57),
];

Color gangColor(String key, {String myId = '', String myGangId = ''}) {
  if (key.isEmpty) return GH.muted;
  if (myGangId.isNotEmpty && key == myGangId) return GH.pink;
  if (myId.isNotEmpty && key == 'p:$myId') return GH.pink;
  final npc = _npcGangColors[key];
  if (npc != null) return npc;
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _gangPalette[h % _gangPalette.length];
}

int _flagSeed(String key) {
  var h = 7;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Lưới 8x8 của lá cờ: nửa trái sinh ngẫu nhiên theo khoá, nửa phải đối xứng.
/// 0 = nền tối, 1 = màu băng, 2 = gạch sáng.
List<List<int>> flagGrid(String key) {
  final rnd = math.Random(_flagSeed(key));
  final grid = List.generate(8, (_) => List.filled(8, 0));
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 4; x++) {
      final v = rnd.nextInt(100);
      final cell = v < 34 ? 0 : (v < 80 ? 1 : 2);
      grid[y][x] = cell;
      grid[y][7 - x] = cell;
    }
  }
  // Sọc nét trên cùng cho ra dáng cờ, bất kể pattern ngẫu nhiên.
  for (var x = 0; x < 4; x++) {
    grid[0][x] = 1;
    grid[0][7 - x] = 1;
  }
  return grid;
}

/// Đổi chuỗi cờ 64 ký tự (0/1/2) thành lưới 8x8; null nếu không hợp lệ.
List<List<int>>? parseFlag(String? flag) {
  if (flag == null || flag.length != 64) return null;
  final grid = List.generate(8, (_) => List.filled(8, 0));
  for (var i = 0; i < 64; i++) {
    final c = flag.codeUnitAt(i) - 0x30;
    if (c < 0 || c > 2) return null;
    grid[i ~/ 8][i % 8] = c;
  }
  return grid;
}

/// Vẽ lưới cờ có sẵn lên canvas — dùng chung cho widget và painter bản đồ.
void paintFlagGrid(
  Canvas canvas,
  Offset topLeft,
  double size,
  List<List<int>> grid,
  Color gang,
) {
  final px = size / 8;
  final paints = [
    Paint()..color = Color.lerp(gang, const Color(0xFF07080C), 0.62)!,
    Paint()..color = gang,
    Paint()..color = Color.lerp(gang, const Color(0xFFFFFFFF), 0.85)!,
  ];
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      canvas.drawRect(
        Rect.fromLTWH(topLeft.dx + x * px, topLeft.dy + y * px, px, px),
        paints[grid[y][x]],
      );
    }
  }
}

/// Vẽ cờ pixel lên canvas — dùng chung cho widget và painter bản đồ.
void paintPixelFlag(
  Canvas canvas,
  Offset topLeft,
  double size,
  String key,
  Color gang,
) {
  paintFlagGrid(canvas, topLeft, size, flagGrid(key), gang);
}

/// Lá cờ pixel của băng/tay chơi: dùng cờ tự vẽ nếu có, không thì sinh từ khoá.
class PixelFlag extends StatelessWidget {
  const PixelFlag({
    super.key,
    required this.gangKey,
    this.flag,
    this.size = 18,
  });

  final String gangKey;

  /// Cờ tự vẽ (64 ký tự 0/1/2); rỗng/null = sinh tự động.
  final String? flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FlagPainter(gangKey, flag),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.gangKey, this.flag);

  final String gangKey;
  final String? flag;

  @override
  void paint(Canvas canvas, Size size) {
    final gang = gangColor(gangKey);
    final grid = parseFlag(flag) ?? flagGrid(gangKey);
    paintFlagGrid(canvas, Offset.zero, size.width, grid, gang);
    paintRoundedRect(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Colors.transparent,
      radius: 2,
      border: GH.line,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) =>
      old.gangKey != gangKey || old.flag != flag;
}
