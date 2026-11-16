import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../scene/paint_utils.dart';

const double _mapW = 1000;
const double _mapH = 1250;

const int _districtSize = 6;

const List<String> _districtNames = [
  'HẺM 12',
  'CHỢ HÒA BÌNH',
  'BẾN XE',
  'SÀI GÒN',
];

const List<Color> _districtTints = [
  Color(0xFFFF2E63),
  Color(0xFF00E5D0),
  Color(0xFF3EE08F),
  Color(0xFFFFC93C),
];

/// 6 ô mỗi quận: 2 cột × 3 hàng, nằm gọn trong ô của quận đó.
Offset _spotOf(int id) {
  final d = id ~/ _districtSize;
  final k = id % _districtSize;
  final left = d % 2 == 0 ? 0.03 : 0.53;
  final top = d < 2 ? 0.03 : 0.53;
  final col = k % 2;
  final row = k ~/ 2;
  return Offset(left + 0.06 + col * 0.31, top + 0.08 + row * 0.125);
}

int _districtOf(int id) => id ~/ _districtSize;

class RpgMapView extends StatefulWidget {
  const RpgMapView({
    super.key,
    required this.territories,
    required this.myId,
    required this.myGangId,
    required this.onTap,
  });

  final List<Territory> territories;
  final String myId;
  final String myGangId;
  final ValueChanged<Territory> onTap;

  @override
  State<RpgMapView> createState() => _RpgMapViewState();
}

class _RpgMapViewState extends State<RpgMapView> {
  final TransformationController _controller = TransformationController();
  Size _viewport = Size.zero;
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _scale => _controller.value.getMaxScaleOnAxis().clamp(0.3, 3.5);

  void _fit() {
    if (_viewport.width <= 0) return;
    final scale = math.min(
          _viewport.width / _mapW,
          _viewport.height / _mapH,
        ) *
        0.97;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport.width - _mapW * scale) / 2,
        (_viewport.height - _mapH * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomBy(double factor) {
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final next = (_scale * factor).clamp(0.3, 3.5);
    final applied = next / _scale;
    final zoom = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _controller.value = zoom * _controller.value;
  }

  Set<int> _heldDistricts() {
    final counts = <int, int>{};
    for (final t in widget.territories) {
      if (widget.myId.isNotEmpty && t.ownerId == 'p:${widget.myId}') {
        final d = _districtOf(t.id);
        counts[d] = (counts[d] ?? 0) + 1;
      }
    }
    return {
      for (final e in counts.entries)
        if (e.value >= _districtSize) e.key,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fitted && _viewport.width > 0) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        final held = _heldDistricts();
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      const Color(0xFF101822),
                      const Color(0xFF05070A),
                    ],
                  ),
                ),
              ),
            ),
            ClipRect(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(260),
                minScale: 0.3,
                maxScale: 3.5,
                child: Container(
                  width: _mapW,
                  height: _mapH,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: GH.line.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CityPainter(held: held),
                        ),
                      ),
                      for (var i = 0; i < widget.territories.length; i++)
                        if (i < 24)
                          Positioned(
                            left: _spotOf(i).dx * _mapW - 50,
                            top: _spotOf(i).dy * _mapH - 28,
                            child: _MapSpot(
                              territory: widget.territories[i],
                              myId: widget.myId,
                              myGangId: widget.myGangId,
                              districtHeld: held.contains(_districtOf(i)),
                              onTap: () =>
                                  widget.onTap(widget.territories[i]),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GH.line),
                ),
                child: Text('Kéo để di chuyển · chụm 2 ngón để zoom',
                    style: labelStyle(size: 9)),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  _zoomBtn(Icons.add_rounded, () => _zoomBy(1.25)),
                  const SizedBox(height: 6),
                  _zoomBtn(Icons.remove_rounded, () => _zoomBy(0.8)),
                  const SizedBox(height: 6),
                  _zoomBtn(Icons.center_focus_strong_rounded, _fit),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: GH.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: GH.line),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6),
          ],
        ),
        child: Icon(icon, size: 18, color: GH.cyan),
      ),
    );
  }
}

class _MapSpot extends StatelessWidget {
  const _MapSpot({
    required this.territory,
    required this.myId,
    required this.myGangId,
    required this.districtHeld,
    required this.onTap,
  });

  final Territory territory;
  final String myId;
  final String myGangId;
  final bool districtHeld;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = territory;
    final mine = myId.isNotEmpty && t.ownerId == 'p:$myId';
    final neutral = t.ownerName.isEmpty;
    final ally = !mine &&
        !neutral &&
        myGangId.isNotEmpty &&
        t.ownerGangId == myGangId;
    final color = mine
        ? GH.pink
        : (ally
            ? GH.green
            : (neutral
                ? GH.muted
                : (t.ownerGangId.isNotEmpty ? GH.gold : GH.cyan)));
    final initial = neutral
        ? '?'
        : t.ownerName.trim().isEmpty
            ? '?'
            : t.ownerName.trim()[0].toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: mine ? 0.32 : 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [
                          color.withValues(alpha: 0.30),
                          const Color(0xFF0C1016),
                        ],
                      ),
                      border: Border.all(
                        color: color,
                        width: mine ? 2.4 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: mine ? 0.45 : 0.18),
                          blurRadius: mine ? 16 : 8,
                        ),
                      ],
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (mine)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GH.pink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 10, color: Colors.black),
                      ),
                    ),
                  if (districtHeld)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GH.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            size: 11, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xF207090D),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.withValues(alpha: mine ? 0.8 : 0.42),
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 5),
                ],
              ),
              child: Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: GH.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  const _CityPainter({required this.held});

  final Set<int> held;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080A0E), Color(0xFF101820), Color(0xFF07090C)],
        ).createShader(rect),
    );

    _districtFog(canvas, size);
    _river(canvas, size);
    _avenues(canvas, size);
    _blocks(canvas, size, rnd);
    _roads(canvas, size);
    _streetlights(canvas, size, rnd);
    _districtPlates(canvas, size);
    _neon(canvas, size, rnd);
    _grain(canvas, size, rnd);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Color(0xAA000000)],
        ).createShader(rect),
    );
  }

  void _districtFog(Canvas c, Size size) {
    for (var d = 0; d < 4; d++) {
      final box = _districtBox(size, d);
      c.drawRect(
        box,
        Paint()
          ..color = (held.contains(d)
                  ? const Color(0xFFFFC93C)
                  : _districtTints[d])
              .withValues(alpha: held.contains(d) ? 0.075 : 0.028),
      );
    }
  }

  Rect _districtBox(Size size, int d) => Rect.fromLTWH(
        (d % 2 == 0 ? 0.03 : 0.53) * size.width,
        (d < 2 ? 0.03 : 0.53) * size.height,
        size.width * 0.44,
        size.height * 0.44,
      );

  void _river(Canvas c, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.47, 0)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.25,
        size.width * 0.55,
        size.height * 0.52,
        size.width * 0.47,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.82,
        size.width * 0.52,
        size.height * 0.92,
        size.width * 0.50,
        size.height,
      );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 84
        ..color = const Color(0xFF07141D),
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 68
        ..color = const Color(0xFF0B2230),
    );
    final wave = Paint()
      ..color = const Color(0xFF1E5266).withValues(alpha: 0.3)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 18; i++) {
      final y = size.height * (0.04 + i * 0.054);
      final x = size.width * (0.44 + math.sin(i * 0.9) * 0.02);
      c.drawLine(Offset(x - 20, y), Offset(x + 20, y + 3), wave);
    }
    final bridge = Paint()..color = const Color(0xFF2A3140);
    final rail = Paint()
      ..color = const Color(0xFF4A5568)
      ..strokeWidth = 2;
    for (final y in [0.22, 0.52, 0.8]) {
      final top = size.height * y;
      c.drawRect(
        Rect.fromLTWH(size.width * 0.39, top, size.width * 0.14, 20),
        bridge,
      );
      c.drawLine(
        Offset(size.width * 0.39, top + 3),
        Offset(size.width * 0.53, top + 3),
        rail,
      );
      c.drawLine(
        Offset(size.width * 0.39, top + 16),
        Offset(size.width * 0.53, top + 16),
        rail,
      );
    }
  }

  void _avenues(Canvas c, Size size) {
    final asphalt = Paint()..color = const Color(0xFF1A2029);
    c.drawRect(
      Rect.fromLTWH(0, size.height * 0.5 - 24, size.width, 48),
      asphalt,
    );
    c.drawRect(
      Rect.fromLTWH(size.width * 0.5 - 24, 0, 48, size.height),
      asphalt,
    );
  }

  void _blocks(Canvas c, Size size, math.Random rnd) {
    final fill = Paint()..color = const Color(0xFF141B25);
    final roof = Paint()..color = const Color(0xFF1B2431);
    final edge = Paint()
      ..color = const Color(0xFF232F3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final park = Paint()..color = const Color(0xFF0E1B16);
    final awning = Paint()..color = const Color(0xFF3A2230);
    final window = Paint()
      ..color = const Color(0xFFFFC93C).withValues(alpha: 0.5);

    for (var d = 0; d < 4; d++) {
      final box = _districtBox(size, d);
      for (var i = 0; i < 12; i++) {
        final bw = box.width * (0.08 + rnd.nextDouble() * 0.13);
        final bh = box.height * (0.05 + rnd.nextDouble() * 0.09);
        final bx = box.left + rnd.nextDouble() * (box.width - bw);
        final by = box.top + rnd.nextDouble() * (box.height - bh);
        final r = Rect.fromLTWH(bx, by, bw, bh);
        final isPark = rnd.nextInt(9) == 0;
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
        c.drawRect(
          r.shift(const Offset(0, 3)),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
        c.drawRRect(rr, isPark ? park : fill);
        if (!isPark) {
          c.drawRect(
            Rect.fromLTWH(r.left + 3, r.top + 3, r.width - 6, 2),
            roof,
          );
          final wins = 2 + rnd.nextInt(4);
          for (var w = 0; w < wins; w++) {
            c.drawRect(
              Rect.fromLTWH(
                r.left + 4 + rnd.nextDouble() * (r.width - 10),
                r.top + 8 + rnd.nextDouble() * (r.height - 12),
                2,
                2,
              ),
              window,
            );
          }
          c.drawRect(
            Rect.fromLTWH(r.right - 11, r.top + 6, 5, 4),
            awning,
          );
        }
        c.drawRRect(rr, edge);
      }
    }

    // Mái tôn chợ cóc.
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.05 + rnd.nextDouble() * 0.38);
      final y = size.height * (0.58 + rnd.nextDouble() * 0.34);
      c.drawRect(
        Rect.fromLTWH(x, y, 42, 12),
        Paint()..color = const Color(0xFF2A2418),
      );
      for (var k = 0; k < 4; k++) {
        c.drawLine(
          Offset(x + k * 10, y),
          Offset(x + k * 10, y + 12),
          Paint()
            ..color = const Color(0xFF3D3420)
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _roads(Canvas c, Size size) {
    final dash = Paint()
      ..color = const Color(0xFF55617A)
      ..strokeWidth = 1.4;
    if (size.width <= 0) return;
    final cx = size.width * 0.5;
    for (var y = 0.0; y < size.height; y += 30) {
      c.drawLine(Offset(cx, y), Offset(cx, y + 15), dash);
    }
    final cy = size.height * 0.5;
    for (var x = 0.0; x < size.width; x += 30) {
      c.drawLine(Offset(x, cy), Offset(x + 15, cy), dash);
    }
    // Vạch sang đường hai bên ngã tư.
    final zebra = Paint()..color = const Color(0xFF39434F);
    for (var i = 0; i < 6; i++) {
      c.drawRect(
        Rect.fromLTWH(cx - 40 + i * 14, cy - 34, 8, 14),
        zebra,
      );
      c.drawRect(
        Rect.fromLTWH(cx - 40 + i * 14, cy + 20, 8, 14),
        zebra,
      );
    }
    for (var i = 0; i < 6; i++) {
      c.drawRect(
        Rect.fromLTWH(cx - 34, cy - 40 + i * 14, 14, 8),
        zebra,
      );
    }
  }

  void _streetlights(Canvas c, Size size, math.Random rnd) {
    for (var i = 0; i < 34; i++) {
      final x = size.width * rnd.nextDouble();
      final y = size.height * rnd.nextDouble();
      final warm = rnd.nextBool();
      final color =
          warm ? const Color(0xFFFFC93C) : const Color(0xFF66E0FF);
      c.drawCircle(Offset(x, y), 2.4, Paint()..color = color);
      c.drawCircle(
        Offset(x, y),
        15,
        Paint()..color = color.withValues(alpha: 0.05),
      );
    }
  }

  void _districtPlates(Canvas c, Size size) {
    for (var d = 0; d < 4; d++) {
      final box = _districtBox(size, d);
      final heldHere = held.contains(d);
      c.drawRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = heldHere ? 3 : 1.2
          ..color = heldHere
              ? const Color(0xFFFFC93C).withValues(alpha: 0.8)
              : const Color(0xFF39455A).withValues(alpha: 0.6),
      );
      final plate = Rect.fromLTWH(
        box.left + 8,
        box.top + 8,
        box.width - 16,
        38,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(6)),
        Paint()..color = const Color(0xCC0A0E14),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (heldHere ? const Color(0xFFFFC93C) : _districtTints[d])
              .withValues(alpha: 0.55),
      );
      paintText(
        c,
        '${_districtNames[d]}  ·  Q${d + 1}',
        Offset(plate.center.dx, plate.top + 6),
        size: 19,
        color: heldHere
            ? const Color(0xFFFFC93C)
            : Colors.white.withValues(alpha: 0.95),
        weight: FontWeight.w900,
        align: TextAlign.center,
      );
      paintText(
        c,
        heldHere ? 'GIỮ TRỌN QUẬN  ·  +10% THU NHẬP' : 'CHƯA GIỮ TRỌN',
        Offset(plate.center.dx, plate.top + 24),
        size: 9.5,
        color: heldHere
            ? const Color(0xFFFFC93C).withValues(alpha: 0.95)
            : _districtTints[d].withValues(alpha: 0.95),
        weight: FontWeight.w800,
        align: TextAlign.center,
      );
    }
  }

  void _neon(Canvas c, Size size, math.Random rnd) {
    const colors = [Color(0xFFFF2E63), Color(0xFF00E5D0), Color(0xFFFFC93C)];
    for (var i = 0; i < 18; i++) {
      final x = size.width * rnd.nextDouble();
      final y = size.height * rnd.nextDouble();
      final color = colors[rnd.nextInt(colors.length)];
      final w = 12 + rnd.nextDouble() * 16;
      final h = 3 + rnd.nextDouble() * 2;
      c.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = color.withValues(alpha: 0.55),
      );
      c.drawRect(
        Rect.fromLTWH(x - 4, y - 4, w + 8, h + 8),
        Paint()..color = color.withValues(alpha: 0.07),
      );
    }
  }

  void _grain(Canvas c, Size size, math.Random rnd) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.028);
    for (var i = 0; i < 700; i++) {
      c.drawRect(
        Rect.fromLTWH(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height,
          1,
          1,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) =>
      oldDelegate.held.length != held.length;
}
