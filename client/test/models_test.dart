import 'package:flutter_test/flutter_test.dart';
import 'package:giang_ho/models.dart';

void main() {
  test('formatMoney theo kiểu Việt', () {
    expect(formatMoney(999), '999');
    expect(formatMoney(1200), '1.2K');
    expect(formatMoney(2500000), '2.5Tr');
    expect(formatMoney(1500000000), '1.5Tỷ');
  });

  test('parse PlayerState + tiến độ cấp bậc', () {
    final s = PlayerState.fromJson({
      'name': 'Tý Hẻm',
      'money': 1200,
      'uy': 250,
      'rank': {'level': 0, 'name': 'Con đỏ', 'uy': 0},
      'nextRank': {'level': 1, 'name': 'Đàn em', 'uy': 500},
      'rate': 22.5,
      'power': 40,
      'weapon': {'name': 'Mã tấu', 'dmg': 12, 'cost': 0},
      'nextWeapon': {'name': 'Phớ', 'dmg': 22, 'cost': 6000},
      'rosterCost': 6000,
      'crew': 2,
      'crewCost': 5286,
      'ownedCount': 1,
      'territoryMul': 1.1,
      'weapons': [
        {'name': 'Mã tấu', 'dmg': 12, 'cost': 0},
        {'name': 'Phớ', 'dmg': 22, 'cost': 6000},
      ],
      'businesses': [
        {
          'id': 'karaoke',
          'name': 'Karaoke Phượng Hoàng',
          'icon': 'K',
          'level': 1,
          'rate': 10.0,
          'upgradeCost': 345,
          'unlocked': true,
          'unlockName': 'Con đỏ',
          'unlockAtRank': 0,
        }
      ],
    });

    expect(s.name, 'Tý Hẻm');
    expect(s.rank.name, 'Con đỏ');
    expect(s.weapons.length, 2);
    expect(s.rankProgress, closeTo(0.5, 0.0001));
    expect(s.businesses.single.name, 'Karaoke Phượng Hoàng');
  });

  test('parse trận đánh và địa bàn', () {
    final r = BrawlResult.fromJson({
      'win': true,
      'events': [
        {
          'at': 0,
          'side': 'me',
          'crit': false,
          'dmg': 24,
          'myHp': 210,
          'enemyHp': 151,
        }
      ],
      'reward': 240,
      'uyGain': 25,
      'power': 40,
      'defense': 55,
      'territoryId': 0,
      'territoryName': 'Hẻm 12',
    });
    expect(r.win, true);
    expect(r.events.single.dmg, 24);
    expect(r.territoryName, 'Hẻm 12');

    final t = Territory.fromJson({
      'id': 0,
      'name': 'Hẻm 12',
      'ownerId': '',
      'ownerName': '',
      'tax': 20,
      'defense': 55,
    });
    expect(t.isNeutral, true);
    expect(t.isMine, false);
  });
}
