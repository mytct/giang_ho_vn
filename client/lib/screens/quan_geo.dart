import 'dart:ui';

/// Số quận mỗi tỉnh — khớp với `DistrictSize` bên server.
const int quanPerProvince = 12;

const int _cols = 3;
const int _rows = 4;
const double _eps = 1e-7;

class PolygonBounds {
  const PolygonBounds(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}

PolygonBounds boundsOf(List<Offset> ring) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final p in ring) {
    if (p.dx < left) left = p.dx;
    if (p.dx > right) right = p.dx;
    if (p.dy < top) top = p.dy;
    if (p.dy > bottom) bottom = p.dy;
  }
  return PolygonBounds(left, top, right, bottom);
}

double polygonArea(List<Offset> ring) {
  if (ring.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

Offset polygonCentroid(List<Offset> ring) {
  if (ring.isEmpty) return Offset.zero;
  var cx = 0.0;
  var cy = 0.0;
  var area = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final cross = a.dx * b.dy - b.dx * a.dy;
    area += cross;
    cx += (a.dx + b.dx) * cross;
    cy += (a.dy + b.dy) * cross;
  }
  if (area.abs() < _eps) {
    var sx = 0.0;
    var sy = 0.0;
    for (final p in ring) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / ring.length, sy / ring.length);
  }
  return Offset(cx / (3 * area), cy / (3 * area));
}

bool _inside(Offset p, double c, bool vertical, bool keepLess) {
  final v = vertical ? p.dx : p.dy;
  return keepLess ? v <= c : v >= c;
}

/// Cắt polygon bằng nửa mặt phẳng (Sutherland–Hodgman).
List<Offset> clipHalfPlane(
  List<Offset> ring,
  double c, {
  required bool vertical,
  required bool keepLess,
}) {
  if (ring.length < 3) return const [];
  final out = <Offset>[];
  var prev = ring.last;
  var prevIn = _inside(prev, c, vertical, keepLess);
  for (final cur in ring) {
    final curIn = _inside(cur, c, vertical, keepLess);
    if (curIn != prevIn) {
      final t = vertical
          ? (c - prev.dx) / (cur.dx - prev.dx)
          : (c - prev.dy) / (cur.dy - prev.dy);
      out.add(Offset(
        prev.dx + (cur.dx - prev.dx) * t,
        prev.dy + (cur.dy - prev.dy) * t,
      ));
    }
    if (curIn) out.add(cur);
    prev = cur;
    prevIn = curIn;
  }
  return out;
}

/// Điểm nằm trong polygon, dùng để đặt nhãn quận.
///
/// Centroid hình học có thể rơi ngoài đa giác lõm, và vòng biên tỉnh trong
/// `vn_map_data` còn tự cắt nhau nên "định lý hai tai" cũng không đáng tin.
/// Ở đây quét vài dòng ngang, lấy trung điểm của khoảng trong-theo-quy-tắc
/// even-odd gần centroid nhất — cùng quy tắc với `Path.contains` nên điểm này
/// luôn hit-test ra đúng mảnh đó.
Offset interiorPoint(List<Offset> ring) {
  if (ring.length < 3) return ring.isEmpty ? Offset.zero : ring.first;
  final b = boundsOf(ring);
  final center = Offset((b.left + b.right) / 2, (b.top + b.bottom) / 2);
  if (b.width <= _eps || b.height <= _eps) return center;

  final target = polygonCentroid(ring);
  Offset? best;
  var bestDist = double.infinity;
  const rows = 9;
  for (var i = 1; i < rows; i++) {
    final y = b.top + b.height * i / rows;
    final xs = <double>[];
    for (var k = 0; k < ring.length; k++) {
      final a = ring[k];
      final c = ring[(k + 1) % ring.length];
      if ((a.dy > y) != (c.dy > y)) {
        xs.add(a.dx + (c.dx - a.dx) * (y - a.dy) / (c.dy - a.dy));
      }
    }
    if (xs.length < 2) continue;
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      if (xs[k + 1] - xs[k] <= _eps) continue;
      final p = Offset((xs[k] + xs[k + 1]) / 2, y);
      final d = (p - target).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
  }
  return best ?? center;
}

bool containsPoint(List<Offset> ring, Offset p) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _cutForArea(List<Offset> ring, PolygonBounds b, double target) {
  var lo = b.top;
  var hi = b.bottom;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    final above = polygonArea(
      clipHalfPlane(ring, mid, vertical: false, keepLess: true),
    );
    if (above < target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

List<Offset> _rect(double left, double top, double right, double bottom) => [
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
    ];

/// Chia một polygon tỉnh thành 12 mảnh liền mạch, diện tích xấp xỉ nhau.
///
/// Cắt 3 cột dọc theo bbox rồi cắt mỗi cột thành 4 hàng theo diện tích, nên
/// mọi mảnh đều nằm trong hình tỉnh và không mảnh nào bị rỗng.
List<List<Offset>> partitionProvincePolygon(List<Offset> ring) {
  if (ring.length < 3) return const [];
  final b = boundsOf(ring);
  if (b.width <= _eps || b.height <= _eps) return const [];

  final out = <List<Offset>>[];
  for (var c = 0; c < _cols; c++) {
    final left = b.left + b.width * c / _cols;
    final right = b.left + b.width * (c + 1) / _cols;
    var col = clipHalfPlane(ring, left, vertical: true, keepLess: false);
    col = clipHalfPlane(col, right, vertical: true, keepLess: true);
    final area = polygonArea(col);

    if (col.length < 3 || area <= _eps) {
      for (var r = 0; r < _rows; r++) {
        out.add(_rect(
          left,
          b.top + b.height * r / _rows,
          right,
          b.top + b.height * (r + 1) / _rows,
        ));
      }
      continue;
    }

    final cb = boundsOf(col);
    final cuts = <double>[];
    for (var r = 1; r < _rows; r++) {
      cuts.add(_cutForArea(col, cb, area * r / _rows));
    }

    for (var r = 0; r < _rows; r++) {
      var slice = col;
      if (r > 0) {
        slice = clipHalfPlane(slice, cuts[r - 1], vertical: false, keepLess: false);
      }
      if (r < _rows - 1) {
        slice = clipHalfPlane(slice, cuts[r], vertical: false, keepLess: true);
      }
      if (slice.length >= 3 && polygonArea(slice) > _eps) {
        out.add(slice);
      } else {
        out.add(_rect(
          cb.left,
          cb.top + cb.height * r / _rows,
          cb.right,
          cb.top + cb.height * (r + 1) / _rows,
        ));
      }
    }
  }
  return out;
}
