import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../scene/paint_utils.dart';
import '../theme.dart';
import 'common.dart';
import 'pixel_flag.dart';

/// Bảng vẽ cờ pixel 8x8 của băng: chạm ô để đổi màu (nền → băng → gạch),
/// có chế độ đối xứng, random và lưu lên server (chỉ băng trưởng/phó).
Future<void> showFlagEditorSheet(
  BuildContext context,
  GameController controller,
  String gangKey,
  String currentFlag,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _FlagEditor(controller: controller, gangKey: gangKey, currentFlag: currentFlag),
  );
}

class _FlagEditor extends StatefulWidget {
  const _FlagEditor({
    required this.controller,
    required this.gangKey,
    required this.currentFlag,
  });

  final GameController controller;
  final String gangKey;
  final String currentFlag;

  @override
  State<_FlagEditor> createState() => _FlagEditorState();
}

class _FlagEditorState extends State<_FlagEditor> {
  late List<List<int>> _grid;
  bool _mirror = true;

  @override
  void initState() {
    super.initState();
    _grid = parseFlag(widget.currentFlag) ?? flagGrid(widget.gangKey);
  }

  String get _encoded =>
      [for (final row in _grid) ...row].join();

  void _tap(int x, int y) {
    setState(() {
      final next = (_grid[y][x] + 1) % 3;
      _grid[y][x] = next;
      if (_mirror) _grid[y][7 - x] = next;
    });
  }

  void _dice() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 4; x++) {
          final v = (rnd >> (y * 4 + x)) % 100;
          final cell = v < 34 ? 0 : (v < 80 ? 1 : 2);
          _grid[y][x] = cell;
          if (_mirror) _grid[y][7 - x] = cell;
        }
      }
    });
  }

  Future<void> _save(String flag) async {
    try {
      await widget.controller.setGangFlag(flag);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gang = gangColor(widget.gangKey);
    final colors = [
      Color.lerp(gang, const Color(0xFF07080C), 0.62)!,
      gang,
      Color.lerp(gang, const Color(0xFFFFFFFF), 0.85)!,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: GH.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GH.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GH.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('CỜ BĂNG',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  PixelFlag(gangKey: widget.gangKey, flag: _encoded, size: 26),
                ],
              ),
              const SizedBox(height: 12),
              // Lưới vẽ 8x8: chạm để đổi màu từng ô.
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final cell = 30.0;
                      final x = (d.localPosition.dx / cell).floor().clamp(0, 7);
                      final y = (d.localPosition.dy / cell).floor().clamp(0, 7);
                      _tap(x, y);
                    },
                    child: CustomPaint(
                      painter: _EditorPainter(
                        grid: _grid,
                        colors: colors,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: GH.line),
                        ),
                      ),
                    ),
                  Text('nền · băng · gạch', style: labelStyle(size: 9.5)),
                  const Spacer(),
                  _chip('GƯƠNG', _mirror ? GH.cyan : GH.muted, () {
                    setState(() => _mirror = !_mirror);
                  }),
                  const SizedBox(width: 6),
                  _chip('RANDOM', GH.gold, _dice),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'VỀ TỰ ĐỘNG',
                      color: GH.muted,
                      height: 42,
                      onTap: () => _save(''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'LƯU CỜ',
                      icon: Icons.check_rounded,
                      color: GH.gold,
                      height: 42,
                      onTap: () => _save(_encoded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: labelStyle(size: 9, color: color)),
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({required this.grid, required this.colors});

  final List<List<int>> grid;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 8;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * px, y * px, px, px),
          Paint()..color = colors[grid[y][x]],
        );
      }
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = GH.line.withValues(alpha: 0.5);
    for (var i = 0; i <= 8; i++) {
      canvas.drawLine(Offset(i * px, 0), Offset(i * px, size.height), line);
      canvas.drawLine(Offset(0, i * px), Offset(size.width, i * px), line);
    }
    paintRoundedRect(
      canvas,
      Offset.zero & size,
      Colors.transparent,
      radius: 4,
      border: GH.line,
    );
  }

  @override
  bool shouldRepaint(covariant _EditorPainter old) => old.grid != grid;
}
