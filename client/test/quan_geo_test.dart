import 'package:flutter_test/flutter_test.dart';
import 'package:giang_ho/screens/quan_geo.dart';
import 'package:giang_ho/screens/rpg_map.dart';
import 'package:giang_ho/screens/vn_map_data.dart';

void main() {
  test('mỗi tỉnh chia đủ 12 quận và phủ kín diện tích', () {
    for (var i = 0; i < vnProvinces.length; i++) {
      final prov = vnProvinces[i];
      var biggest = prov.rings.first;
      for (final r in prov.rings) {
        if (polygonArea(r) > polygonArea(biggest)) biggest = r;
      }
      final layout = partitionProvincePolygon(biggest);
      expect(layout.length, quanPerProvince, reason: prov.name);

      var sum = 0.0;
      for (final poly in layout) {
        expect(polygonArea(poly), greaterThan(0), reason: prov.name);
        sum += polygonArea(poly);
      }
      expect(sum / polygonArea(biggest), closeTo(1, 0.01), reason: prov.name);
    }
  });

  test('chạm vào tâm mảnh nào cũng ra đúng quận đó', () {
    for (var i = 0; i < vnProvinces.length; i++) {
      final layout = provinceDistricts(i);
      for (var slot = 0; slot < layout.length; slot++) {
        final c = interiorPoint(layout[slot]);
        var hit = -1;
        for (var k = 0; k < layout.length; k++) {
          if (containsPoint(layout[k], c)) hit = k;
        }
        expect(hit, slot, reason: '${vnProvinces[i].name} Q${slot + 1}');
      }
    }
  });
}
