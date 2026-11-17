import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../scene/paint_utils.dart';
import '../theme.dart';
import 'vn_map_data.dart';

const double _mapW = 900;
const double _mapH = 1600;

const int _quanPerProvince = 12;

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

String _groupOf(Territory t) =>
    t.ownerGangId.isNotEmpty ? t.ownerGangId : t.ownerId;

Color _groupColor(String key, String myGangId) {
  if (key.isEmpty) return GH.muted;
  final npc = _npcGangColors[key];
  if (npc != null) return npc;
  if (myGangId.isNotEmpty && key == myGangId) return GH.pink;
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _gangPalette[h % _gangPalette.length];
}

class _ProvinceInfo {
  _ProvinceInfo({
    required this.color,
    required this.label,
    required this.count,
    required this.mine,
    required this.quans,
  });

  final Color color;
  final String label;
  final int count;
  final bool mine;
  final List<Territory> quans;
}

class RpgMapView extends StatefulWidget {
  const RpgMapView({
    super.key,
    required this.territories,
    required this.myId,
    required this.myGangId,
    required this.onTapProvince,
  });

  final List<Territory> territories;
  final String myId;
  final String myGangId;
  final ValueChanged<int> onTapProvince;

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

  List<_ProvinceInfo> _infos() {
    final byProvince = <int, List<Territory>>{};
    for (final t in widget.territories) {
      byProvince.putIfAbsent(t.provinceId, () => []).add(t);
    }
    final out = <_ProvinceInfo>[];
    for (var i = 0; i < vnProvinces.length; i++) {
      final quans = byProvince[i] ?? const <Territory>[];
      final counts = <String, int>{};
      final names = <String, String>{};
      for (final t in quans) {
        final key = _groupOf(t);
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
        names.putIfAbsent(key, () => t.ownerName);
      }
      if (counts.isEmpty) {
        out.add(_ProvinceInfo(
          color: GH.muted,
          label: 'ĐẤT TRỐNG',
          count: 0,
          mine: false,
          quans: quans,
        ));
        continue;
      }
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final mine = quans.where((t) {
        return widget.myId.isNotEmpty && t.ownerId == 'p:${widget.myId}';
      }).length;
      out.add(_ProvinceInfo(
        color: _groupColor(top.key, widget.myGangId),
        label: names[top.key] ?? '?',
        count: top.value,
        mine: mine >= _quanPerProvince,
        quans: quans,
      ));
    }
    return out;
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
        final infos = _infos();
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
                          painter: _MapPainter(
                            infos: infos,
                            selected: _selected,
                            showLabels: _scale > 0.62,
                          ),
                        ),
                      ),
                      for (var i = 0; i < vnProvinces.length; i++)
                        Positioned(
                          left: vnProvinces[i].cx * _mapW - 22,
                          top: vnProvinces[i].cy * _mapH - 22,
                          child: _ProvinceBadge(
                            info: infos[i],
                            selected: _selected == i,
                            onTap: () {
                              setState(() => _selected = i);
                              widget.onTapProvince(i);
                            },
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
                child: Text('Chạm tỉnh để xem 12 quận · kéo & zoom',
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

class _ProvinceBadge extends StatelessWidget {
  const _ProvinceBadge({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _ProvinceInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = info.mine ? GH.gold : info.color;
    final initial = info.label.trim().isEmpty
        ? '?'
        : info.label.trim()[0].toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xD9080B10),
          border: Border.all(
            color: color,
            width: selected ? 3 : 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.55 : 0.25),
              blurRadius: selected ? 16 : 8,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (info.count > 0)
              Positioned(
                bottom: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: GH.red,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Text(
                    '${info.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.infos,
    required this.selected,
    required this.showLabels,
  });

  final List<_ProvinceInfo> infos;
  final int selected;
  final bool showLabels;

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

    for (var i = 0; i < vnProvinces.length; i++) {
      final prov = vnProvinces[i];
      final info = infos[i];
      final color = info.mine ? GH.gold : info.color;
      final paths = <Path>[];
      for (final ring in prov.rings) {
        if (ring.length < 3) continue;
        final p = Path()
          ..moveTo(ring[0].dx * size.width, ring[0].dy * size.height);
        for (var k = 1; k < ring.length; k++) {
          p.lineTo(ring[k].dx * size.width, ring[k].dy * size.height);
        }
        paths.add(p..close());
      }
      for (final path in paths) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        canvas.drawPath(
          path,
          Paint()..color = color.withValues(alpha: info.count > 0 ? 0.34 : 0.12),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected == i ? 3.2 : 1.2
            ..color = color.withValues(alpha: selected == i ? 1 : 0.7),
        );
      }
      if (showLabels) {
        paintText(
          canvas,
          prov.name.toUpperCase(),
          Offset(prov.cx * size.width, prov.cy * size.height + 26),
          size: 8,
          color: Colors.white.withValues(alpha: 0.92),
          weight: FontWeight.w900,
          align: TextAlign.center,
        );
      }
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
      old.selected != selected || old.showLabels != showLabels;
}
