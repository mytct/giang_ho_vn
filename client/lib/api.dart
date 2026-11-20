import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MapPayload {
  MapPayload(this.territories, this.state);
  final List<Territory> territories;
  final PlayerState state;
}

class AttackPayload {
  AttackPayload(this.result, this.state);
  final BrawlResult result;
  final PlayerState state;
}

String defaultBaseUrl() {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) return override;
  if (kIsWeb) return 'http://localhost:8089';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8089';
  }
  return 'http://localhost:8089';
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl();

  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['X-Token'] = token!;

    try {
      final http.Response res;
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(
              const Duration(seconds: 8),
            );
      } else {
        res = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 8));
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final data = (decoded as Map).cast<String, dynamic>();
      if (res.statusCode >= 400) {
        throw ApiException(data['error'] as String? ?? 'Lỗi server (${res.statusCode})');
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server không phản hồi');
    } on http.ClientException {
      throw ApiException('Không kết nối được server ($baseUrl)');
    } on FormatException {
      throw ApiException('Server trả dữ liệu lạ');
    }
  }

  Future<String> devLogin([String name = 'Đại Ca A']) async {
    final data = await _send('POST', '/api/dev/login', body: {'name': name});
    token = data['token'] as String;
    return token!;
  }

  Future<String> login(String name) async {
    final data = await _send('POST', '/api/login', body: {'name': name});
    token = data['token'] as String;
    return token!;
  }

  Future<PlayerState> state() async {
    final data = await _send('GET', '/api/state');
    return PlayerState.fromJson(data);
  }

  Future<MapPayload> map() async {
    final data = await _send('GET', '/api/map');
    return MapPayload(
      (data['territories'] as List? ?? [])
          .map((e) => Territory.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<PlayerState> upgrade(String businessId, int region) async {
    final data = await _send('POST', '/api/upgrade', body: {
      'business': businessId,
      'district': region,
      'token': token,
    });
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> recruit() async {
    final data = await _send('POST', '/api/recruit', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> recruitMinions(int count) async {
    final data = await _send('POST', '/api/minion/recruit',
        body: {'count': count, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> buyMinionGear(String id, int count) async {
    final data = await _send('POST', '/api/minion/gear',
        body: {'id': id, 'count': count, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> healMinions(int count) async {
    final data = await _send('POST', '/api/minion/heal',
        body: {'count': count, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> upgradeWeapon() async {
    final data = await _send('POST', '/api/weapon', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<AttackPayload> attack(int territoryId) async {
    final data = await _send('POST', '/api/attack',
        body: {'territory': territoryId, 'token': token});
    return AttackPayload(
      BrawlResult.fromJson((data['result'] as Map).cast<String, dynamic>()),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<PlayerState> claimMission(String id) async {
    final data = await _send('POST', '/api/mission/claim',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> spendPoint(String stat) async {
    final data = await _send('POST', '/api/level/spend',
        body: {'stat': stat, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> claimDaily(String id) async {
    final data = await _send('POST', '/api/daily/claim',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<(List<GangInfo>, List<RelationEdge>)> diplomacy() async {
    final data = await _send('GET', '/api/diplomacy');
    final gangs = (data['gangs'] as List? ?? [])
        .map((e) => GangInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final edges = (data['edges'] as List? ?? [])
        .map((e) => RelationEdge.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (gangs, edges);
  }

  Future<List<GangInfo>> gangs() async {
    final data = await _send('GET', '/api/gangs');
    return (data['gangs'] as List? ?? [])
        .map((e) => GangInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<PlayerState> createGang(String name) async {
    final data = await _send('POST', '/api/gang/create',
        body: {'name': name, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> joinGang(String id) async {
    final data = await _send('POST', '/api/gang/join',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> leaveGang() async {
    final data = await _send('POST', '/api/gang/leave', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> allyGang(String id) async {
    final data = await _send('POST', '/api/gang/ally',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> unallyGang(String id) async {
    final data = await _send('POST', '/api/gang/unally',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> demandTribute(String id) async {
    final data = await _send('POST', '/api/gang/tribute',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> breakTribute() async {
    final data = await _send('POST', '/api/gang/break-tribute',
        body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> declareWar(String id) async {
    final data = await _send('POST', '/api/gang/war',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<List<InboxMsg>> inbox() async {
    final data = await _send('GET', '/api/inbox');
    return (data['messages'] as List? ?? [])
        .map((e) => InboxMsg.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<PlayerState> upgradeTerritory(int territory) async {
    final data = await _send('POST', '/api/territory/upgrade',
        body: {'territory': territory, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> buildWork(int district, String work) async {
    final data = await _send('POST', '/api/city/build',
        body: {'district': district, 'work': work, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<(List<Chapter>, int)> campaign() async {
    final data = await _send('GET', '/api/campaign');
    final chapters = (data['chapters'] as List? ?? [])
        .map((e) => Chapter.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (chapters, asInt(data['current']));
  }

  Future<(BrawlResult, PlayerState)> fightChapter(int index) async {
    final data = await _send('POST', '/api/campaign/fight',
        body: {'index': index, 'token': token});
    return (
      BrawlResult.fromJson((data['result'] as Map).cast<String, dynamic>()),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<PlayerState> prestige() async {
    final data = await _send('POST', '/api/prestige', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> assignGuard(
      int territory, int crew, int minions, String general) async {
    final data = await _send('POST', '/api/crew/assign', body: {
      'territory': territory,
      'crew': crew,
      'minions': minions,
      'general': general,
      'token': token,
    });
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> setFormation(String kind) async {
    final data = await _send('POST', '/api/crew/formation',
        body: {'kind': kind, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> gangFlag(String flag) async {
    final data = await _send('POST', '/api/gang/flag',
        body: {'flag': flag, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> autoAssignGuards() async {
    final data = await _send('POST', '/api/crew/auto', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> bribeHeat() async {
    final data =
        await _send('POST', '/api/heat/bribe', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<List<BountyInfo>> bounties() async {
    final data = await _send('GET', '/api/bounties');
    return (data['rows'] as List? ?? [])
        .map((e) => BountyInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<PlayerState> setBounty(String id, int amount) async {
    final data = await _send('POST', '/api/bounty',
        body: {'id': id, 'amount': amount, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<DefenseReplay> defenseBattle(String id) async {
    final data = await _send('POST', '/api/inbox/battle',
        body: {'id': id, 'token': token});
    final rec = (data['record'] as Map).cast<String, dynamic>();
    return DefenseReplay(
      attackerName: rec['attackerName'] as String? ?? '?',
      result: BrawlResult.fromJson(
          (rec['result'] as Map).cast<String, dynamic>()),
    );
  }

  Future<PlayerState> raiseRacket(String id) async {
    final data = await _send('POST', '/api/business/racket',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> recruitGeneral() async {
    final data =
        await _send('POST', '/api/general/recruit', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> trainGeneral(String id) async {
    final data = await _send('POST', '/api/general/train',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<GangChatInfo> gangChat() async {
    final data = await _send('GET', '/api/gang/chat');
    return GangChatInfo.fromJson(data);
  }

  Future<GangChatInfo> sendGangChat(String text) async {
    final data = await _send('POST', '/api/gang/chat',
        body: {'text': text, 'token': token});
    return GangChatInfo.fromJson(data);
  }

  Future<GangChatInfo> promoteGangMember(String id) async {
    final data = await _send('POST', '/api/gang/promote',
        body: {'targetId': id, 'token': token});
    return GangChatInfo.fromJson(data);
  }

  Future<GangChatInfo> payoutTreasury(int amount) async {
    final data = await _send('POST', '/api/gang/payout',
        body: {'amount': amount, 'token': token});
    return GangChatInfo.fromJson(data);
  }

  Future<PlayerState> upgradeGang(String kind) async {
    final data = await _send('POST', '/api/gang/upgrade',
        body: {'kind': kind, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> readInbox([String id = '']) async {
    final data = await _send('POST', '/api/inbox/read',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<(List<ContractInfo>, ContractInfo?)> contracts() async {
    final data = await _send('GET', '/api/contracts');
    final offers = (data['offers'] as List? ?? [])
        .map((e) => ContractInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final active = data['active'] == null
        ? null
        : ContractInfo.fromJson(
            (data['active'] as Map).cast<String, dynamic>());
    return (offers, active);
  }

  Future<PlayerState> acceptContract(String id) async {
    final data = await _send('POST', '/api/contract/accept',
        body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<PlayerState> claimContract() async {
    final data =
        await _send('POST', '/api/contract/claim', body: {'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<(CasinoResult, PlayerState)> casino(String choice, int bet) async {
    final data = await _send('POST', '/api/casino',
        body: {'choice': choice, 'bet': bet, 'token': token});
    return (
      CasinoResult.fromJson((data['result'] as Map).cast<String, dynamic>()),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<(BossInfo, PlayerState)> boss() async {
    final data = await _send('GET', '/api/boss');
    return (
      BossInfo.fromJson((data['boss'] as Map).cast<String, dynamic>()),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<(BossHitResult, PlayerState)> bossHit() async {
    final data =
        await _send('POST', '/api/boss/hit', body: {'token': token});
    return (
      BossHitResult.fromJson((data['result'] as Map).cast<String, dynamic>()),
      PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>()),
    );
  }

  Future<PlayerState> buyItem(String id) async {
    final data =
        await _send('POST', '/api/shop/item', body: {'id': id, 'token': token});
    return PlayerState.fromJson((data['state'] as Map).cast<String, dynamic>());
  }

  Future<List<RankingRow>> ranking() async {
    final data = await _send('GET', '/api/ranking');
    return (data['rows'] as List? ?? [])
        .map((e) => RankingRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
