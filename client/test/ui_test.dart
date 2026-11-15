import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giang_ho/models.dart';
import 'package:giang_ho/scene/alley_game.dart';
import 'package:giang_ho/scene/brawl_game.dart';
import 'package:giang_ho/screens/crew_screen.dart';
import 'package:giang_ho/screens/home_screen.dart';
import 'package:giang_ho/screens/ranking_screen.dart';
import 'package:giang_ho/screens/diplomacy_sheet.dart';
import 'package:giang_ho/controller.dart';
import 'package:giang_ho/api.dart';

PlayerState sampleState({int crew = 1, String gangId = ''}) =>
    PlayerState.fromJson({
      'name': 'Tý Hẻm',
      'money': 125000,
      'uy': 900,
      'rank': {'level': 1, 'name': 'Đàn em', 'uy': 500},
      'nextRank': {'level': 2, 'name': 'Đại ca', 'uy': 2000},
      'rate': 32.0,
      'power': 40,
      'weapon': {'name': 'Mã tấu', 'dmg': 12, 'cost': 0},
      'nextWeapon': {'name': 'Phớ', 'dmg': 22, 'cost': 6000},
      'rosterCost': 6000,
      'crew': crew,
      'crewCost': 5286,
      'ownedCount': 2,
      'territoryMul': 1.2,
      'weapons': [
        {'name': 'Mã tấu', 'dmg': 12, 'cost': 0},
        {'name': 'Phớ', 'dmg': 22, 'cost': 6000},
        {'name': 'Súng lục', 'dmg': 38, 'cost': 30000},
      ],
      'gangId': gangId,
      'gangName': gangId.isEmpty ? '' : 'Băng Rắn Độc',
      'gangMembers': gangId.isEmpty ? 0 : 3,
      'gangBonus': gangId.isEmpty ? 1 : 1.06,
      'maxOwned': 4,
      'daily': [
        {
          'id': 'd_win',
          'title': 'Dằn mặt',
          'desc': 'Thắng 2 trận chiếm địa bàn',
          'progress': 0,
          'target': 2,
          'rewardMoney': 550,
          'rewardUy': 17,
          'claimed': false,
          'claimable': false,
        },
        {
          'id': 'd_upgrade',
          'title': 'Làm ăn',
          'desc': 'Nâng cấp cơ sở 2 lần',
          'progress': 1,
          'target': 2,
          'rewardMoney': 550,
          'rewardUy': 17,
          'claimed': false,
          'claimable': false,
        },
      ],
      'level': 3,
      'xp': 120,
      'xpNext': 525,
      'points': 1,
      'stats': {'hp': 1, 'dmg': 2, 'armor': 0},
      'crewSkills': [
        {
          'id': 'dao',
          'name': 'Dao Bén',
          'desc': '+15% sát thương',
          'rarity': 'Thường',
        },
        {
          'id': 'satthu',
          'name': 'Sát Thủ',
          'desc': '+25% sát thương, đòn hiểm 2 lượt/lần',
          'rarity': 'Đặc biệt',
        },
      ],
      'missions': [
        {
          'id': 'muaso',
          'title': 'Mở hàng',
          'desc': 'Nâng cấp bất kỳ cơ sở nào 1 lần',
          'progress': 1,
          'target': 1,
          'rewardMoney': 500,
          'rewardUy': 20,
          'claimed': false,
          'claimable': true,
        },
        {
          'id': 'bangdang',
          'title': 'Cắm cờ',
          'desc': 'Giữ 3 địa bàn cùng lúc',
          'progress': 2,
          'target': 3,
          'rewardMoney': 3000,
          'rewardUy': 150,
          'claimed': false,
          'claimable': false,
        },
      ],
      'businesses': [
        {
          'id': 'karaoke',
          'name': 'Karaoke Phượng Hoàng',
          'icon': 'K',
          'level': 2,
          'rate': 20.0,
          'upgradeCost': 1560,
          'unlocked': true,
          'unlockName': 'Con đỏ',
          'unlockAtRank': 0,
        },
        {
          'id': 'doxe',
          'name': 'Xưởng Độ Xe',
          'icon': 'X',
          'level': 0,
          'rate': 0.0,
          'upgradeCost': 300,
          'unlocked': false,
          'unlockName': 'Đại ca',
          'unlockAtRank': 2,
        },
      ],
    });

class _FakeDiplomacyApi extends ApiClient {
  _FakeDiplomacyApi(this.gangList, this.edgeList);

  final List<GangInfo> gangList;
  final List<RelationEdge> edgeList;

  @override
  Future<(List<GangInfo>, List<RelationEdge>)> diplomacy() async =>
      (gangList, edgeList);
}

void main() {
  testWidgets('scene sân băng render không lỗi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 190));
    final game = AlleyGame(rate: 42);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('trận chém replay xong và báo kết thúc', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    var finished = false;
    final result = BrawlResult.fromJson({
      'win': true,
      'events': [
        {
          'at': 0,
          'side': 'me',
          'crit': false,
          'dmg': 24,
          'myHp': 210,
          'enemyHp': 151,
        },
        {
          'at': 380,
          'side': 'enemy',
          'crit': false,
          'dmg': 14,
          'myHp': 196,
          'enemyHp': 151,
        },
      ],
      'reward': 240,
      'uyGain': 25,
      'power': 40,
      'defense': 55,
      'territoryId': 0,
      'territoryName': 'Hẻm 12',
      'xp': 45,
      'levelups': 1,
      'levelupMoney': 400,
    });
    final game = BrawlGame(
      result: result,
      myName: 'Tý Hẻm',
      enemyName: 'Băng Chuột Cống',
      myCount: 3,
      enemyCount: 3,
      onFinished: () => finished = true,
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(finished, isTrue);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('home hiện tiền, cơ sở và cơ sở khoá', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final controller = GameController(ApiClient());
    controller.booting = false;
    controller.state = sampleState();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeScreen(controller: controller)),
    ));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Tý Hẻm'), findsOneWidget);
    expect(find.text('Karaoke Phượng Hoàng'), findsOneWidget);
    expect(find.text('Xưởng Độ Xe'), findsOneWidget);
    expect(find.text('Cần đạt Đại ca'), findsOneWidget);
    expect(find.text('125.0K'), findsOneWidget);
    expect(find.text('NHIỆM VỤ'), findsOneWidget);
    expect(find.text('NHẬN 1'), findsOneWidget);
    expect(find.textContaining('1 phần thưởng chờ nhận'), findsOneWidget);
    expect(find.text('Lv 3'), findsOneWidget);
    expect(find.text('+1 điểm'), findsOneWidget);

    await tester.tap(find.text('Lv 3'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Máu'), findsOneWidget);
    expect(find.text('Sát thương'), findsOneWidget);
    expect(find.text('Lì đòn'), findsOneWidget);
    expect(find.text('+25 máu (1 điểm)'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('crew hiện kỹ năng tiềm ẩn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final controller = GameController(ApiClient());
    controller.booting = false;
    controller.state = sampleState(crew: 2);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CrewScreen(controller: controller)),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('Cấp 3'), findsOneWidget);
    expect(find.textContaining('Dao Bén'), findsOneWidget);
    expect(find.textContaining('Sát Thủ'), findsOneWidget);
    expect(find.text('ĐẶC BIỆT'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('băng đảng hiện buff và trạng thái chiến', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final controller = GameController(ApiClient());
    controller.booting = false;
    controller.state = sampleState(crew: 2, gangId: 'g1');
    controller.gangs = [
      GangInfo.fromJson({
        'id': 'g1',
        'name': 'Băng Rắn Độc',
        'members': 3,
        'maxMembers': 10,
        'power': 180,
        'owned': 6,
        'leader': 'Tý Hẻm',
        'isMine': true,
        'warName': 'Băng Cá Sấu',
        'tier': 1,
        'relation': 'self',
        'wars': 1,
        'allies': 0,
        'treasury': 1200,
        'tributes': 0,
        'warUntil':
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 20 * 60,
      }),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RankingScreen(controller: controller)),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('Băng Rắn Độc'), findsWidgets);
    expect(find.text('+6% lực'), findsOneWidget);
    expect(find.text('T1'), findsWidgets);
    expect(find.text('BĂNG MÀY'), findsOneWidget);
    expect(find.textContaining('Đang chiến với Băng Cá Sấu'), findsOneWidget);
    expect(find.text('TUYÊN CHIẾN'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('quỹ băng hiện 3 gói tiêu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final controller = GameController(ApiClient());
    controller.booting = false;
    controller.state = sampleState(gangId: 'g1');
    controller.gangs = [
      GangInfo.fromJson({
        'id': 'g1',
        'name': 'Băng Rắn Độc',
        'members': 2,
        'maxMembers': 10,
        'power': 146,
        'owned': 2,
        'leader': 'Tý Hẻm',
        'isMine': true,
        'tier': 1,
        'relation': 'self',
        'allies': 1,
        'wars': 1,
        'treasury': 16000,
        'level': 2,
        'upgradeCost': 5000,
      }),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RankingScreen(controller: controller)),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('QUỸ'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('QUỸ BĂNG'), findsOneWidget);
    expect(find.text('Nâng lực băng'), findsOneWidget);
    expect(find.text('Khiên băng 30 phút'), findsOneWidget);
    expect(find.text('Chiến phí 30 phút'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('sơ đồ ngoại giao vẽ và liệt kê quan hệ', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final gangs = [
      GangInfo.fromJson({
        'id': 'g1',
        'name': 'Băng Rắn Độc',
        'tier': 1,
        'power': 146,
        'members': 2,
        'relation': 'self',
      }),
      GangInfo.fromJson({
        'id': 'g2',
        'name': 'Băng Cá Sấu',
        'tier': 2,
        'power': 86,
        'members': 1,
        'relation': 'ally',
      }),
      GangInfo.fromJson({
        'id': 'g3',
        'name': 'Băng Ó Đen',
        'tier': 2,
        'power': 86,
        'members': 1,
        'relation': 'war',
      }),
    ];
    final edges = [
      RelationEdge.fromJson({
        'from': 'g1',
        'to': 'g2',
        'kind': 'ally',
        'until': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      }),
      RelationEdge.fromJson({
        'from': 'g1',
        'to': 'g3',
        'kind': 'war',
        'until': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600,
      }),
      RelationEdge.fromJson({
        'from': 'g3',
        'to': 'g1',
        'kind': 'tribute',
        'until': 0,
      }),
    ];
    final api = _FakeDiplomacyApi(gangs, edges);
    final controller = GameController(api)
      ..booting = false
      ..state = sampleState(gangId: 'g1')
      ..gangs = gangs
      ..edges = edges;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showDiplomacySheet(context, controller),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('SƠ ĐỒ NGOẠI GIAO'), findsOneWidget);
    expect(find.textContaining('LIÊN MINH'), findsOneWidget);
    expect(find.textContaining('ĐANG CHIẾN'), findsOneWidget);
    expect(find.text('NỘP CỐNG'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('bảng băng đảng + quan hệ ngoại giao', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final controller = GameController(ApiClient());
    controller.booting = false;
    controller.state = sampleState(crew: 2, gangId: 'g1');
    controller.gangs = [
      GangInfo.fromJson({
        'id': 'g1',
        'name': 'Băng Rắn Độc',
        'members': 3,
        'maxMembers': 10,
        'power': 180,
        'owned': 6,
        'leader': 'Tý Hẻm',
        'isMine': true,
        'tier': 1,
        'relation': 'self',
        'allies': 1,
        'wars': 1,
        'treasury': 1200,
        'warScore': 4,
        'warOpen': true,
      }),
      GangInfo.fromJson({
        'id': 'g2',
        'name': 'Băng Cá Sấu',
        'members': 8,
        'maxMembers': 10,
        'power': 150,
        'owned': 9,
        'leader': 'Cá Mập',
        'isMine': false,
        'tier': 2,
        'relation': 'war',
        'allies': 1,
        'wars': 2,
        'treasury': 5000,
      }),
      GangInfo.fromJson({
        'id': 'g3',
        'name': 'Băng Chuột Cống',
        'members': 2,
        'maxMembers': 10,
        'power': 60,
        'owned': 2,
        'leader': 'Chuột Nhỏ',
        'isMine': false,
        'tier': 3,
        'relation': 'ally',
      }),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RankingScreen(controller: controller)),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('BẢNG BĂNG ĐẢNG'), findsOneWidget);
    expect(find.text('T1'), findsWidgets);
    expect(find.text('T2'), findsWidgets);
    expect(find.text('T3'), findsWidgets);
    expect(find.text('ĐANG CHIẾN'), findsOneWidget);
    expect(find.text('ĐỒNG MINH'), findsOneWidget);
    expect(find.textContaining('Đang thu cống'), findsNothing);

    await tester.tap(find.text('ĐANG CHIẾN'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('ĐANG CHIẾN. Chém vào địa bàn'), findsOneWidget);
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
