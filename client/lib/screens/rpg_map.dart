import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../scene/paint_utils.dart';

const double _mapW = 1200;
const double _mapH = 1500;

const List<Offset> _spots = [
  Offset(0.20, 0.12),
  Offset(0.38, 0.09),
  Offset(0.12, 0.26),
  Offset(0.33, 0.24),
  Offset(0.68, 0.11),
  Offset(0.86, 0.16),
  Offset(0.64, 0.27),
  Offset(0.86, 0.32),
  Offset(0.14, 0.42),
  Offset(0.34, 0.40),
  Offset(0.16, 0.56),
  Offset(0.37, 0.55),
  Offset(0.66, 0.44),
  Offset(0.85, 0.42),
  Offset(0.63, 0.57),
  Offset(0.86, 0.56),
  Offset(0.19, 0.71),
  Offset(0.39, 0.73),
  Offset(0.14, 0.86),
  Offset(0.36, 0.88),
  Offset(0.63, 0.72),
  Offset(0.86, 0.70),
  Offset(0.62, 0.87),
  Offset(0.85, 0.86),
];

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
    final scale = math.max(
          _viewport.width / _mapW,
          _viewport.height / _mapH,
        ) *
        0.92;
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
        return Stack(
          children: [
            ClipRect(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(260),
                minScale: 0.3,
                maxScale: 3.5,
                child: SizedBox(
                  width: _mapW,
                  height: _mapH,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _CityPainter()),
                      ),
                      for (var i = 0; i < widget.territories.length; i++)
                        if (i < _spots.length)
                          Positioned(
                            left: _spots[i].dx * _mapW - 52,
                            top: _spots[i].dy * _mapH - 72,
                            child: _MapSpot(
                              territory: widget.territories[i],
                              myId: widget.myId,
                              myGangId: widget.myGangId,
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
                  color: Colors.black.withValues(alpha: 0.55),
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
    required this.onTap,
  });

  final Territory territory;
  final String myId;
  final String myGangId;
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

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.35),
                    GH.panel.withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(color: color, width: mine ? 2.4 : 1.6),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: mine ? 16 : 8,
                  ),
                ],
              ),
              child: Icon(
                mine
                    ? Icons.flag_rounded
                    : (ally
                        ? Icons.handshake_rounded
                        : (neutral
                            ? Icons.circle_outlined
                            : Icons.shield_rounded)),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Column(
                children: [
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: GH.text),
                  ),
                  Text(
                    'Lv${t.level} · ${t.defense}',
                    style: labelStyle(size: 7.5, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  const _CityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B0D14), Color(0xFF121722), Color(0xFF0A0B10)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // City blocks.
    final block = Paint()..color = const Color(0xFF11151F);
    final edge = Paint()
      ..color = const Color(0xFF1B2230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const cols = 6;
    const rows = 8;
    final bw = size.width / cols;
    final bh = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * bw + 14,
          r * bh + 14,
          bw - 34,
          bh - 34,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), block);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), edge);
      }
    }

    // Roads.
    final road = Paint()
      ..color = const Color(0xFF1E2431)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final lane = Paint()
      ..color = const Color(0xFF2A3242)
      ..strokeWidth = 1.2;
    for (var c = 1; c < cols; c++) {
      final x = c * bw - 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
      for (var y = 0.0; y < size.height; y += 34) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 16), lane);
      }
    }
    for (var r = 1; r < rows; r++) {
      final y = r * bh - 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
      for (var x = 0.0; x < size.width; x += 34) {
        canvas.drawLine(Offset(x, y), Offset(x + 16, y), lane);
      }
    }

    // River.
    final river = Path()
      ..moveTo(size.width * 0.52, 0)
      ..cubicTo(size.width * 0.46, size.height * 0.28,
          size.width * 0.62, size.height * 0.55,
          size.width * 0.54, size.height);
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..color = const Color(0xFF0E2233),
    );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1E4E66).withValues(alpha: 0.6),
    );

    // District labels.
    const districts = [
      ('QUẬN 1', 0.24, 0.04),
      ('QUẬN 2', 0.78, 0.04),
      ('QUẬN 3', 0.24, 0.35),
      ('QUẬN 4', 0.78, 0.35),
      ('QUẬN 5', 0.24, 0.65),
      ('QUẬN 6', 0.78, 0.65),
    ];
    for (final d in districts) {
      paintText(
        canvas,
        d.$1,
        Offset(size.width * d.$2, size.height * d.$3),
        size: 26,
        color: Colors.white.withValues(alpha: 0.06),
        weight: FontWeight.w900,
        align: TextAlign.center,
      );
    }

    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Color(0xAA000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) => false;
}
