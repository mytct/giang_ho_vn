import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class GameController extends ChangeNotifier {
  GameController(this.api);

  final ApiClient api;

  PlayerState? state;
  List<Territory> territories = const [];
  List<RankingRow> ranking = const [];
  List<GangInfo> gangs = const [];
  List<RelationEdge> edges = const [];
  List<BountyInfo> bounties = const [];
  List<Chapter> chapters = const [];
  int chapterIndex = 0;
  List<InboxMsg> inbox = const [];
  List<ContractInfo> offers = const [];
  BossInfo? boss;
  bool booting = true;
  bool busy = false;

  Timer? _poll;

  bool get loggedIn => state != null;

  Future<void> tryRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        api.token = token;
        state = await api.state();
        _startPolling();
      }
    } on ApiException {
      api.token = null;
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> demoLogin() async {
    await api.devLogin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    state = await api.state();
    _startPolling();
    notifyListeners();
  }

  Future<void> login(String name) async {
    final token = await api.login(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    state = await api.state();
    _startPolling();
    notifyListeners();
  }

  Future<void> logout() async {
    _poll?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    api.token = null;
    state = null;
    territories = const [];
    ranking = const [];
    notifyListeners();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (busy || api.token == null) return;
      api.state().then((s) {
        state = s;
        notifyListeners();
      }).catchError((Object _) {});
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => _guard(() async {
        state = await api.state();
      });

  Future<void> loadMap() async {
    final payload = await api.map();
    territories = payload.territories;
    state = payload.state;
    notifyListeners();
  }

  Future<void> loadRanking() async {
    ranking = await api.ranking();
    notifyListeners();
  }

  Future<void> upgrade(String businessId, int district) => _guard(() async {
        state = await api.upgrade(businessId, district);
      });

  Future<void> recruit() => _guard(() async {
        state = await api.recruit();
      });

  Future<void> raiseRacket(String businessId) => _guard(() async {
        state = await api.raiseRacket(businessId);
      });

  Future<void> recruitGeneral() => _guard(() async {
        state = await api.recruitGeneral();
      });

  Future<void> trainGeneral(String id) => _guard(() async {
        state = await api.trainGeneral(id);
      });

  Future<void> recruitMinions(int count) => _guard(() async {
        state = await api.recruitMinions(count);
      });

  Future<void> buyMinionGear(String id, int count) => _guard(() async {
        state = await api.buyMinionGear(id, count);
      });

  Future<void> healMinions(int count) => _guard(() async {
        state = await api.healMinions(count);
      });

  Future<void> upgradeWeapon() => _guard(() async {
        state = await api.upgradeWeapon();
      });

  Future<void> claimMission(String id) => _guard(() async {
        state = await api.claimMission(id);
      });

  Future<void> claimDaily(String id) => _guard(() async {
        state = await api.claimDaily(id);
      });

  Future<void> loadGangs() async {
    gangs = await api.gangs();
    notifyListeners();
  }

  Future<void> loadDiplomacy() async {
    final (g, e) = await api.diplomacy();
    gangs = g;
    edges = e;
    notifyListeners();
  }

  Future<void> upgradeTerritory(int id) => _guard(() async {
        state = await api.upgradeTerritory(id);
        final payload = await api.map();
        territories = payload.territories;
      });

  Future<void> buildWork(int district, String work) => _guard(() async {
        state = await api.buildWork(district, work);
      });

  Future<void> loadCampaign() async {
    final (list, current) = await api.campaign();
    chapters = list;
    chapterIndex = current;
    notifyListeners();
  }

  Future<BrawlResult> fightChapter(int index) async {
    busy = true;
    notifyListeners();
    try {
      final (result, s) = await api.fightChapter(index);
      state = s;
      final (list, current) = await api.campaign();
      chapters = list;
      chapterIndex = current;
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> prestige() => _guard(() async {
        state = await api.prestige();
        final payload = await api.map();
        territories = payload.territories;
        ranking = await api.ranking();
        final (list, current) = await api.campaign();
        chapters = list;
        chapterIndex = current;
      });

  Future<void> assignGuard(int territory, int crew, int minions) =>
      _guard(() async {
        state = await api.assignGuard(territory, crew, minions);
      });

  Future<void> setFormation(String kind) => _guard(() async {
        state = await api.setFormation(kind);
      });

  Future<void> bribeHeat() => _guard(() async {
        state = await api.bribeHeat();
      });

  Future<void> loadBounties() async {
    bounties = await api.bounties();
    notifyListeners();
  }

  Future<void> setBounty(String id, int amount) => _guard(() async {
        state = await api.setBounty(id, amount);
        ranking = await api.ranking();
        bounties = await api.bounties();
      });

  Future<DefenseReplay> loadDefenseBattle(String id) async {
    return api.defenseBattle(id);
  }

  Future<void> upgradeGang(String kind) => _guard(() async {
        state = await api.upgradeGang(kind);
        gangs = await api.gangs();
      });

  Future<void> loadInbox() => _guard(() async {
        inbox = await api.inbox();
      });

  Future<void> readInbox() => _guard(() async {
        state = await api.readInbox();
        inbox = await api.inbox();
      });

  Future<void> loadContracts() => _guard(() async {
        final (o, a) = await api.contracts();
        offers = o;
        if (state != null) state = state!;
      });

  Future<void> acceptContract(String id) => _guard(() async {
        state = await api.acceptContract(id);
        final (o, _) = await api.contracts();
        offers = o;
      });

  Future<void> claimContract() => _guard(() async {
        state = await api.claimContract();
        final (o, _) = await api.contracts();
        offers = o;
      });

  Future<CasinoResult> playCasino(String choice, int bet) async {
    busy = true;
    notifyListeners();
    try {
      final (result, s) = await api.casino(choice, bet);
      state = s;
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadBoss() => _guard(() async {
        final (b, s) = await api.boss();
        boss = b;
        state = s;
      });

  Future<BossHitResult> hitBoss() async {
    busy = true;
    notifyListeners();
    try {
      final (result, s) = await api.bossHit();
      state = s;
      final (b, _) = await api.boss();
      boss = b;
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> buyItem(String id) => _guard(() async {
        state = await api.buyItem(id);
      });

  Future<void> createGang(String name) => _guard(() async {
        state = await api.createGang(name);
        gangs = await api.gangs();
      });

  Future<void> joinGang(String id) => _guard(() async {
        state = await api.joinGang(id);
        gangs = await api.gangs();
      });

  Future<void> leaveGang() => _guard(() async {
        state = await api.leaveGang();
        gangs = await api.gangs();
      });

  Future<void> allyGang(String id) => _guard(() async {
        state = await api.allyGang(id);
        gangs = await api.gangs();
      });

  Future<void> unallyGang(String id) => _guard(() async {
        state = await api.unallyGang(id);
        gangs = await api.gangs();
      });

  Future<void> demandTribute(String id) => _guard(() async {
        state = await api.demandTribute(id);
        gangs = await api.gangs();
      });

  Future<void> breakTribute() => _guard(() async {
        state = await api.breakTribute();
        gangs = await api.gangs();
      });

  Future<void> declareWar(String id) => _guard(() async {
        state = await api.declareWar(id);
        gangs = await api.gangs();
      });

  Future<void> spendPoint(String stat) => _guard(() async {
        state = await api.spendPoint(stat);
      });

  Future<BrawlResult> attack(int territoryId) async {
    busy = true;
    notifyListeners();
    try {
      final payload = await api.attack(territoryId);
      state = payload.state;
      return payload.result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> reloadTerritoriesQuietly() async {
    try {
      final payload = await api.map();
      territories = payload.territories;
      state = payload.state;
      notifyListeners();
    } on ApiException {
      // giữ dữ liệu cũ nếu mất mạng
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
