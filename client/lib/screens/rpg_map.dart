import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../scene/paint_utils.dart';
import '../theme.dart';
import 'quan_geo.dart';
import 'vn_map_data.dart';

const double _mapW = 900;
const double _mapH = 1600;

const Map<String, Color> _npcGangColors = {
  'npc:ran': Color(0xFF3EE08F),
  'npc:ca': Color(0xFF00E5D0),
  'npc:o': Color(0xFF9B6BFF),
  'npc:chuot': Color(0xFFB58A5A),
};

const List<Color> _gangPalette = [
  Color(0xFFFF2E63),
  Color(0xFF00E5D0),
  Color(0xFF3EE08F),
  Color(0xFFFFC93C),
  Color(0xFF9B6BFF),
  Color(0xFFFF7A00),
  Color(0xFF4DA3FF),
];

/// Khoá nhóm chủ sở hữu dùng để tô màu: cùng băng (hoặc cùng tay chơi khi
/// chưa có băng) thì cùng màu.
String territoryGroup(Territory t) =>
    t.ownerGangId.isNotEmpty ? t.ownerGangId : t.ownerId;

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

final Map<int, List<List<Offset>>> _layoutCache = {};

List<List<Offset>> provinceDistricts(int province) {
  return _layoutCache.putIfAbsent(province, () {
    final rings = vnProvinces[province].rings;
    if (rings.isEmpty) return const <List<Offset>>[];
    var main = rings.first;
    for (final r in rings) {
      if (polygonArea(r) > polygonArea(main)) main = r;
    }
    return partitionProvincePolygon(main);
  });
}

Path _ringPath(List<Offset> ring, Size size) {
  final path = Path()
    ..moveTo(ring[0].dx * size.width, ring[0].dy * size.height);
  for (var i = 1; i < ring.length; i++) {
    path.lineTo(ring[i].dx * size.width, ring[i].dy * size.height);
  }
  return path..close();
}

class RpgMapView extends StatefulWidget {
  const RpgMapView({
    super.key,
    required this.territories,
    required this.myId,
    required this.myGangId,
    required this.onTapTerritory,
  });

  final List<Territory> territories;
  final String myId;
  final String myGangId;
  final ValueChanged<int> onTapTerritory;

  @override
  State<RpgMapView> createState() => _RpgMapViewState();
}

class _RpgMapViewState extends State<RpgMapView> {
  final TransformationController _controller = TransformationController();
  Size _viewport = Size.zero;
  bool _fitted = false;
  int _selected = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    super.dispose();
  }

  double get _scale => _controller.value.getMaxScaleOnAxis().clamp(0.3, 6);

  void _fit() {
    if (_viewport.width <= 0) return;
    final scale = math.min(_viewport.width / _mapW, _viewport.height / _mapH) *
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
    final next = (_scale * factor).clamp(0.3, 6.0);
    final applied = next / _scale;
    final zoom = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _controller.value = zoom * _controller.value;
  }

  int _districtAt(Offset local) {
    const size = Size(_mapW, _mapH);
    for (var i = 0; i < vnProvinces.length; i++) {
      final layout = provinceDistricts(i);
      for (var slot = 0; slot < layout.length; slot++) {
        final rings = layout[slot];
        if (rings.length < 3) continue;
        if (_ringPath(rings, size).contains(local)) {
          return i * quanPerProvince + slot;
        }
      }
    }
    return -1;
  }

  void _onTapUp(TapUpDetails details) {
    final id = _districtAt(details.localPosition);
    if (id < 0) return;
    setState(() => _selected = id);
    widget.onTapTerritory(id);
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
        final byId = <int, Territory>{
          for (final t in widget.territories) t.id: t,
        };
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [Color(0xFF0B1420), Color(0xFF04060A)],
                  ),
                ),
              ),
            ),
            ClipRect(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(300),
                minScale: 0.3,
                maxScale: 6,
                child: SizedBox(
                  width: _mapW,
                  height: _mapH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    child: CustomPaint(
                      size: const Size(_mapW, _mapH),
                      painter: _MapPainter(
                        territories: byId,
                        myId: widget.myId,
                        myGangId: widget.myGangId,
                        selected: _selected,
                        showProvinceLabels: _scale > 0.62 && _scale <= 2.2,
                        showDistrictLabels: _scale > 1.25,
                        showTileProvince: _scale > 2.2,
                      ),
                    ),
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
                child: Text('Chạm một quận để chém · kéo & zoom',
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

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.territories,
    required this.myId,
    required this.myGangId,
    required this.selected,
    required this.showProvinceLabels,
    required this.showDistrictLabels,
    required this.showTileProvince,
  });

  final Map<int, Territory> territories;
  final String myId;
  final String myGangId;
  final int selected;
  final bool showProvinceLabels;
  final bool showDistrictLabels;
  final bool showTileProvince;

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
          colors: [Color(0xFF061019), Color(0xFF0B1A24), Color(0xFF04080D)],
        ).createShader(rect),
    );
    _sea(canvas, size, rnd);
    _districts(canvas, size);
    _provinceBorders(canvas, size);
    if (showProvinceLabels || showDistrictLabels) {
      _labels(canvas, size);
    }

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

  void _districts(Canvas canvas, Size size) {
    for (var i = 0; i < vnProvinces.length; i++) {
      final layout = provinceDistricts(i);
      if (layout.isEmpty) continue;
      for (var slot = 0; slot < layout.length; slot++) {
        final t = territories[i * quanPerProvince + slot];
        final key = t == null ? '' : territoryGroup(t);
        final owned = key.isNotEmpty;
        final color = gangColor(key, myId: myId, myGangId: myGangId);
        final path = _ringPath(layout[slot], size);
        final isSelected = selected == i * quanPerProvince + slot;

        if (isSelected) {
          canvas.drawPath(
            path,
            Paint()
              ..color = GH.gold.withValues(alpha: 0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = owned
                ? color.withValues(alpha: 0.46)
                : GH.panel2.withValues(alpha: 0.55),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2.4 : 0.8
            ..color = isSelected
                ? GH.gold
                : GH.ink.withValues(alpha: owned ? 0.9 : 0.65),
        );
      }

      // Đảo/khúc rời của tỉnh: tô theo quận gần nhất để vẫn đúng màu băng.
      final rings = vnProvinces[i].rings;
      if (rings.length > 1 && layout.isNotEmpty) {
        final centers = [for (final r in layout) interiorPoint(r)];
        final main = _mainRing(rings);
        for (final ring in rings) {
          if (identical(ring, main) || ring.length < 3) continue;
          final c = polygonCentroid(ring);
          var best = 0;
          var bestDist = double.infinity;
          for (var k = 0; k < centers.length; k++) {
            final d = (centers[k] - c).distanceSquared;
            if (d < bestDist) {
              bestDist = d;
              best = k;
            }
          }
          final t = territories[i * quanPerProvince + best];
          final key = t == null ? '' : territoryGroup(t);
          final color = gangColor(key, myId: myId, myGangId: myGangId);
          final path = _ringPath(ring, size);
          canvas.drawPath(
            path,
            Paint()..color = color.withValues(alpha: key.isEmpty ? 0.2 : 0.4),
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = GH.ink.withValues(alpha: 0.8),
          );
        }
      }
    }
  }

  List<Offset> _mainRing(List<List<Offset>> rings) {
    var main = rings.first;
    for (final r in rings) {
      if (polygonArea(r) > polygonArea(main)) main = r;
    }
    return main;
  }

  void _provinceBorders(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Color(0xFF7FE7FF).withValues(alpha: 0.5);
    for (final prov in vnProvinces) {
      for (final ring in prov.rings) {
        if (ring.length < 3) continue;
        canvas.drawPath(_ringPath(ring, size), border);
      }
    }
  }

  void _labels(Canvas canvas, Size size) {
    for (var i = 0; i < vnProvinces.length; i++) {
      final prov = vnProvinces[i];
      if (showProvinceLabels && !showDistrictLabels) {
        paintText(
          canvas,
          prov.name.toUpperCase(),
          Offset(prov.cx * size.width, prov.cy * size.height + 26),
          size: 8,
          color: Colors.white.withValues(alpha: 0.92),
          weight: FontWeight.w900,
          align: TextAlign.center,
          glow: Colors.black,
          glowBlur: 3,
        );
      }
      if (!showDistrictLabels) continue;
      final layout = provinceDistricts(i);
      for (var slot = 0; slot < layout.length; slot++) {
        final c = interiorPoint(layout[slot]);
        final t = territories[i * quanPerProvince + slot];
        final key = t == null ? '' : territoryGroup(t);
        final px = c.dx * size.width;
        final py = c.dy * size.height;
        // Zoom sâu thì mỗi ô tự mang tên tỉnh: tỉnh nào cũng có Quận 1..12
        // nên "Q1" suông không nói lên ô nào.
        if (showTileProvince) {
          paintText(
            canvas,
            prov.name.toUpperCase(),
            Offset(px, py - 12),
            size: 6,
            color: Colors.white.withValues(alpha: 0.55),
            weight: FontWeight.w800,
            align: TextAlign.center,
            glow: Colors.black,
            glowBlur: 3,
          );
        }
        paintText(
          canvas,
          showTileProvince ? 'QUẬN ${slot + 1}' : 'Q${slot + 1}',
          Offset(px, py - 3),
          size: showTileProvince ? 7.5 : 7,
          color: key.isEmpty
              ? Colors.white.withValues(alpha: 0.6)
              : gangColor(key, myId: myId, myGangId: myGangId),
          weight: FontWeight.w900,
          align: TextAlign.center,
          glow: Colors.black,
          glowBlur: 4,
        );
      }
    }
  }

  void _sea(Canvas c, Size size, math.Random rnd) {
    final wave = Paint()
      ..color = const Color(0xFF1E5266).withValues(alpha: 0.16)
      ..strokeWidth = 1.1;
    for (var i = 0; i < 70; i++) {
      final y = size.height * rnd.nextDouble();
      final x = size.width * rnd.nextDouble();
      c.drawLine(Offset(x - 24, y), Offset(x + 24, y + 3), wave);
    }
    paintText(
      c,
      'BIỂN ĐÔNG',
      Offset(size.width * 0.84, size.height * 0.42),
      size: 13,
      color: const Color(0xFF2E6B80).withValues(alpha: 0.8),
      weight: FontWeight.w900,
      align: TextAlign.center,
    );
  }

  void _grain(Canvas c, Size size, math.Random rnd) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.022);
    for (var i = 0; i < 900; i++) {
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
  bool shouldRepaint(covariant _MapPainter old) =>
      old.territories != territories ||
      old.selected != selected ||
      old.showProvinceLabels != showProvinceLabels ||
      old.showDistrictLabels != showDistrictLabels ||
      old.showTileProvince != showTileProvince ||
      old.myId != myId ||
      old.myGangId != myGangId;
}
