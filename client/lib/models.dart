int asInt(dynamic v) => v is num ? v.toInt() : 0;
double asDouble(dynamic v) => v is num ? v.toDouble() : 0.0;

class RankInfo {
  const RankInfo({required this.level, required this.name, required this.uy});

  final int level;
  final String name;
  final int uy;

  factory RankInfo.fromJson(Map<String, dynamic> j) => RankInfo(
        level: asInt(j['level']),
        name: j['name'] as String? ?? 'Con đỏ',
        uy: asInt(j['uy']),
      );
}

class WeaponInfo {
  const WeaponInfo({required this.name, required this.dmg, required this.cost});

  final String name;
  final int dmg;
  final int cost;

  factory WeaponInfo.fromJson(Map<String, dynamic> j) => WeaponInfo(
        name: j['name'] as String? ?? '',
        dmg: asInt(j['dmg']),
        cost: asInt(j['cost']),
      );
}

class RelationEdge {
  const RelationEdge({
    required this.from,
    required this.to,
    required this.kind,
    required this.until,
  });

  final String from;
  final String to;
  final String kind;
  final int until;

  factory RelationEdge.fromJson(Map<String, dynamic> j) => RelationEdge(
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        until: asInt(j['until']),
      );
}

class GuardSlot {
  const GuardSlot({
    required this.territoryId,
    required this.name,
    required this.count,
    required this.tax,
    this.minions = 0,
    this.province = '',
    this.generalId = '',
    this.general = '',
  });

  final int territoryId;
  final String name;
  final int count;
  final int tax;
  final int minions;
  final String province;
  final String generalId;
  final String general;

  String get fullName => province.isEmpty ? name : '$province · $name';

  factory GuardSlot.fromJson(Map<String, dynamic> j) => GuardSlot(
        territoryId: asInt(j['territoryId']),
        name: j['name'] as String? ?? '',
        province: j['province'] as String? ?? '',
        count: asInt(j['count']),
        tax: asInt(j['tax']),
        minions: asInt(j['minions']),
        generalId: j['generalId'] as String? ?? '',
        general: j['general'] as String? ?? '',
      );
}

class MinionGearInfo {
  const MinionGearInfo({
    required this.id,
    required this.name,
    required this.desc,
    required this.cost,
    required this.power,
    required this.owned,
  });

  final String id;
  final String name;
  final String desc;
  final int cost;
  final int power;
  final int owned;

  factory MinionGearInfo.fromJson(Map<String, dynamic> j) => MinionGearInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        cost: asInt(j['cost']),
        power: asInt(j['power']),
        owned: asInt(j['owned']),
      );
}

class BountyInfo {
  const BountyInfo({
    required this.id,
    required this.name,
    required this.amount,
    required this.power,
    required this.rank,
  });

  final String id;
  final String name;
  final int amount;
  final int power;
  final String rank;

  factory BountyInfo.fromJson(Map<String, dynamic> j) => BountyInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        amount: asInt(j['amount']),
        power: asInt(j['power']),
        rank: j['rank'] as String? ?? '',
      );
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.desc,
    required this.bossName,
    required this.bossPower,
    required this.needOwned,
    required this.needUy,
    required this.rewardMoney,
    required this.rewardUy,
    required this.rewardXp,
    required this.status,
  });

  final int id;
  final String title;
  final String desc;
  final String bossName;
  final int bossPower;
  final int needOwned;
  final int needUy;
  final int rewardMoney;
  final int rewardUy;
  final int rewardXp;
  final String status;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: asInt(j['id']),
        title: j['title'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        bossName: j['bossName'] as String? ?? '',
        bossPower: asInt(j['bossPower']),
        needOwned: asInt(j['needOwned']),
        needUy: asInt(j['needUy']),
        rewardMoney: asInt(j['rewardMoney']),
        rewardUy: asInt(j['rewardUy']),
        rewardXp: asInt(j['rewardXp']),
        status: j['status'] as String? ?? 'locked',
      );
}

class DefenseReplay {
  const DefenseReplay({required this.attackerName, required this.result});
  final String attackerName;
  final BrawlResult result;
}

class CrewSkill {
  const CrewSkill({
    required this.id,
    required this.name,
    required this.desc,
    required this.rarity,
  });

  final String id;
  final String name;
  final String desc;
  final String rarity;

  factory CrewSkill.fromJson(Map<String, dynamic> j) => CrewSkill(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        rarity: j['rarity'] as String? ?? 'Thường',
      );
}

class GangInfo {
  const GangInfo({
    required this.id,
    required this.name,
    required this.flag,
    required this.members,
    required this.maxMembers,
    required this.power,
    required this.owned,
    required this.leader,
    required this.isMine,
    required this.warName,
    required this.warUntil,
    required this.warScore,
    required this.warOpen,
    required this.tier,
    required this.relation,
    required this.wars,
    required this.allies,
    required this.treasury,
    required this.tributeToName,
    required this.tributes,
    required this.level,
    required this.boostUntil,
    required this.shieldCooldownUntil,
    required this.warCooldownUntil,
    required this.upgradeCost,
    required this.warSettled,
  });

  final String id;
  final String name;
  final String flag;
  final int members;
  final int maxMembers;
  final int power;
  final int owned;
  final String leader;
  final bool isMine;
  final String warName;
  final int warUntil;
  final int warScore;
  final bool warOpen;
  final int tier;
  final String relation;
  final int wars;
  final int allies;
  final int treasury;
  final String tributeToName;
  final int tributes;
  final int level;
  final int boostUntil;
  final int shieldCooldownUntil;
  final int warCooldownUntil;
  final int upgradeCost;
  final bool warSettled;

  factory GangInfo.fromJson(Map<String, dynamic> j) => GangInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        flag: j['flag'] as String? ?? '',
        members: asInt(j['members']),
        maxMembers: asInt(j['maxMembers']),
        power: asInt(j['power']),
        owned: asInt(j['owned']),
        leader: j['leader'] as String? ?? '',
        isMine: j['isMine'] as bool? ?? false,
        warName: j['warName'] as String? ?? '',
        warUntil: asInt(j['warUntil']),
        warScore: asInt(j['warScore']),
        warOpen: j['warOpen'] as bool? ?? false,
        tier: asInt(j['tier']),
        relation: j['relation'] as String? ?? 'neutral',
        wars: asInt(j['wars']),
        allies: asInt(j['allies']),
        treasury: asInt(j['treasury']),
        tributeToName: j['tributeToName'] as String? ?? '',
        tributes: asInt(j['tributes']),
        level: asInt(j['level']),
        boostUntil: asInt(j['boostUntil']),
        shieldCooldownUntil: asInt(j['shieldCooldownUntil']),
        warCooldownUntil: asInt(j['warCooldownUntil']),
        upgradeCost: asInt(j['upgradeCost']),
        warSettled: j['warSettled'] as bool? ?? false,
      );
}

class InboxMsg {
  const InboxMsg({
    required this.id,
    required this.text,
    required this.kind,
    required this.at,
    required this.fromName,
    required this.territoryId,
    required this.battleId,
    required this.revengeUntil,
    required this.read,
  });

  final String id;
  final String text;
  final String kind;
  final int at;
  final String fromName;
  final int territoryId;
  final String battleId;
  final int revengeUntil;
  final bool read;

  bool get revengeActive =>
      revengeUntil > DateTime.now().millisecondsSinceEpoch ~/ 1000;

  factory InboxMsg.fromJson(Map<String, dynamic> j) => InboxMsg(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        kind: j['kind'] as String? ?? 'system',
        at: asInt(j['at']),
        fromName: j['fromName'] as String? ?? '',
        territoryId: asInt(j['territoryId']),
        battleId: j['battleId'] as String? ?? '',
        revengeUntil: asInt(j['revengeUntil']),
        read: j['read'] as bool? ?? false,
      );
}

class ContractInfo {
  const ContractInfo({
    required this.id,
    required this.title,
    required this.desc,
    required this.kind,
    required this.target,
    required this.progress,
    required this.deposit,
    required this.rewardMoney,
    required this.rewardUy,
    required this.remaining,
    required this.active,
    required this.complete,
  });

  final String id;
  final String title;
  final String desc;
  final String kind;
  final int target;
  final int progress;
  final int deposit;
  final int rewardMoney;
  final int rewardUy;
  final int remaining;
  final bool active;
  final bool complete;

  double get ratio => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  factory ContractInfo.fromJson(Map<String, dynamic> j) => ContractInfo(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        target: asInt(j['target']),
        progress: asInt(j['progress']),
        deposit: asInt(j['deposit']),
        rewardMoney: asInt(j['rewardMoney']),
        rewardUy: asInt(j['rewardUy']),
        remaining: asInt(j['remaining']),
        active: j['active'] as bool? ?? false,
        complete: j['complete'] as bool? ?? false,
      );
}

class BossRow {
  const BossRow({required this.name, required this.damage});
  final String name;
  final int damage;

  factory BossRow.fromJson(Map<String, dynamic> j) => BossRow(
        name: j['name'] as String? ?? '',
        damage: asInt(j['damage']),
      );
}

class BossInfo {
  const BossInfo({
    required this.week,
    required this.hp,
    required this.maxHp,
    required this.myDamage,
    required this.tickets,
    required this.defeated,
    required this.top,
  });

  final String week;
  final int hp;
  final int maxHp;
  final int myDamage;
  final int tickets;
  final bool defeated;
  final List<BossRow> top;

  double get ratio => maxHp == 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  factory BossInfo.fromJson(Map<String, dynamic> j) => BossInfo(
        week: j['week'] as String? ?? '',
        hp: asInt(j['hp']),
        maxHp: asInt(j['maxHp']),
        myDamage: asInt(j['myDamage']),
        tickets: asInt(j['tickets']),
        defeated: j['defeated'] as bool? ?? false,
        top: (j['top'] as List? ?? [])
            .map((e) => BossRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class CasinoResult {
  const CasinoResult({
    required this.roll,
    required this.sum,
    required this.win,
    required this.payout,
  });

  final List<int> roll;
  final int sum;
  final bool win;
  final int payout;

  factory CasinoResult.fromJson(Map<String, dynamic> j) => CasinoResult(
        roll: (j['roll'] as List? ?? []).map(asInt).toList(),
        sum: asInt(j['sum']),
        win: j['win'] as bool? ?? false,
        payout: asInt(j['payout']),
      );
}

class BossHitResult {
  const BossHitResult({
    required this.damage,
    required this.reward,
    required this.uy,
    required this.bossHp,
    required this.defeated,
  });

  final int damage;
  final int reward;
  final int uy;
  final int bossHp;
  final bool defeated;

  factory BossHitResult.fromJson(Map<String, dynamic> j) => BossHitResult(
        damage: asInt(j['damage']),
        reward: asInt(j['reward']),
        uy: asInt(j['uy']),
        bossHp: asInt(j['bossHp']),
        defeated: j['defeated'] as bool? ?? false,
      );
}

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.desc,
    required this.progress,
    required this.target,
    required this.rewardMoney,
    required this.rewardUy,
    required this.claimed,
    required this.claimable,
  });

  final String id;
  final String title;
  final String desc;
  final int progress;
  final int target;
  final int rewardMoney;
  final int rewardUy;
  final bool claimed;
  final bool claimable;

  double get ratio => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);
  bool get done => progress >= target;

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        progress: asInt(j['progress']),
        target: asInt(j['target']),
        rewardMoney: asInt(j['rewardMoney']),
        rewardUy: asInt(j['rewardUy']),
        claimed: j['claimed'] as bool? ?? false,
        claimable: j['claimable'] as bool? ?? false,
      );
}

class GeneralInfo {
  const GeneralInfo({
    required this.id,
    required this.name,
    required this.level,
    required this.power,
    required this.trainCost,
    required this.skillA,
    required this.skillB,
  });

  final String id;
  final String name;
  final int level;
  final int power;
  final int trainCost;
  final CrewSkill skillA;
  final CrewSkill skillB;

  factory GeneralInfo.fromJson(Map<String, dynamic> j) => GeneralInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        level: asInt(j['level']),
        power: asInt(j['power']),
        trainCost: asInt(j['trainCost']),
        skillA: CrewSkill.fromJson(
            (j['skillA'] as Map?)?.cast<String, dynamic>() ?? {}),
        skillB: CrewSkill.fromJson(
            (j['skillB'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
}

class GangMessage {
  const GangMessage({
    required this.at,
    required this.name,
    required this.role,
    required this.text,
  });

  final int at;
  final String name;
  final String role;
  final String text;

  factory GangMessage.fromJson(Map<String, dynamic> j) => GangMessage(
        at: asInt(j['at']),
        name: j['name'] as String? ?? '',
        role: j['role'] as String? ?? 'member',
        text: j['text'] as String? ?? '',
      );
}

class GangMemberInfo {
  const GangMemberInfo({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  factory GangMemberInfo.fromJson(Map<String, dynamic> j) => GangMemberInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        role: j['role'] as String? ?? 'member',
      );
}

class GangChatInfo {
  const GangChatInfo({
    required this.messages,
    required this.members,
    required this.myRole,
    required this.treasury,
    required this.log,
  });

  final List<GangMessage> messages;
  final List<GangMemberInfo> members;
  final String myRole;
  final int treasury;
  final List<String> log;

  factory GangChatInfo.fromJson(Map<String, dynamic> j) => GangChatInfo(
        messages: (j['messages'] as List? ?? [])
            .map((e) => GangMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        members: (j['members'] as List? ?? [])
            .map((e) => GangMemberInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        myRole: j['myRole'] as String? ?? 'member',
        treasury: asInt(j['treasury']),
        log: (j['log'] as List? ?? [])
            .map((e) => (e as Map)['text'] as String? ?? '')
            .toList(),
      );
}

class BusinessInfo {
  const BusinessInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.level,
    required this.rate,
    required this.upgradeCost,
    required this.unlocked,
    required this.unlockName,
    this.racket = 0,
    this.racketCost = 0,
    this.region = 0,
    this.land = true,
  });

  final String id;
  final String name;
  final String icon;
  final int level;
  final double rate;
  final int upgradeCost;
  final bool unlocked;
  final String unlockName;
  final int racket;
  final int racketCost;
  final int region;
  final bool land;

  factory BusinessInfo.fromJson(Map<String, dynamic> j) => BusinessInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? '?',
        level: asInt(j['level']),
        rate: asDouble(j['rate']),
        upgradeCost: asInt(j['upgradeCost']),
        unlocked: j['unlocked'] as bool? ?? false,
        unlockName: j['unlockName'] as String? ?? '',
        racket: asInt(j['racket']),
        racketCost: asInt(j['racketCost']),
        region: asInt(j['region']),
        land: j['land'] as bool? ?? true,
      );
}

class CityWorkInfo {
  const CityWorkInfo({required this.level, required this.cost});

  final int level;
  final int cost;

  factory CityWorkInfo.fromJson(Map<String, dynamic> j) => CityWorkInfo(
        level: asInt(j['level']),
        cost: asInt(j['cost']),
      );
}

class WorkInfo {
  const WorkInfo({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.maxLevel,
  });

  final String id;
  final String name;
  final String desc;
  final String icon;
  final int maxLevel;

  factory WorkInfo.fromJson(Map<String, dynamic> j) => WorkInfo(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        icon: j['icon'] as String? ?? '?',
        maxLevel: asInt(j['maxLevel']),
      );
}

class CityInfo {
  const CityInfo({
    required this.district,
    required this.name,
    required this.held,
    required this.total,
    required this.mine,
    required this.works,
    required this.goodsRate,
    required this.incomeMul,
    required this.defense,
    this.region = 0,
  });

  final int district;
  final String name;
  final int held;
  final int total;
  final bool mine;
  final Map<String, CityWorkInfo> works;
  final double goodsRate;
  final double incomeMul;
  final int defense;
  final int region;

  factory CityInfo.fromJson(Map<String, dynamic> j) => CityInfo(
        district: asInt(j['district']),
        name: j['name'] as String? ?? '',
        held: asInt(j['held']),
        total: asInt(j['total']),
        mine: j['mine'] as bool? ?? false,
        region: asInt(j['region']),
        works: (j['works'] as Map? ?? {}).map(
          (k, v) => MapEntry(
            k as String,
            CityWorkInfo.fromJson((v as Map).cast<String, dynamic>()),
          ),
        ),
        goodsRate: asDouble(j['goodsRate']),
        incomeMul: asDouble(j['incomeMul']),
        defense: asInt(j['defense']),
      );

  CityWorkInfo? work(String id) => works[id];
}

class PlayerState {
  const PlayerState({
    required this.name,
    required this.money,
    required this.uy,
    required this.rank,
    required this.nextRank,
    required this.rate,
    required this.power,
    required this.weapon,
    required this.nextWeapon,
    required this.rosterCost,
    required this.crew,
    required this.crewCost,
    required this.ownedCount,
    required this.territoryMul,
    required this.weapons,
    required this.businesses,
    required this.missions,
    required this.crewSkills,
    required this.gangFlags,
    required this.level,
    required this.xp,
    required this.xpNext,
    required this.points,
    required this.statHp,
    required this.statDmg,
    required this.statArmor,
    required this.daily,
    required this.dailyResetAt,
    required this.gangId,
    required this.gangName,
    required this.gangMembers,
    required this.gangBonus,
    required this.maxOwned,
    required this.unread,
    required this.contract,
    required this.casinoLeft,
    required this.seasonKey,
    required this.seasonUy,
    required this.items,
    required this.playerId,
    required this.heat,
    required this.heatPenalty,
    required this.bribeCost,
    required this.formation,
    required this.guards,
    this.guardedMinions = 0,
    this.availableMinions = 0,
    required this.availableCrew,
    required this.minions,
    required this.minionHealthy,
    required this.wounds,
    required this.minionPower,
    required this.minionRecruitCost,
    required this.minionHealCost,
    required this.maxMinions,
    required this.minionGear,
    this.upkeep = 0,
    this.goods = 0,
    this.goodsRate = 0,
    this.goodsUpkeep = 0,
    this.cities = const [],
    this.works = const [],
    this.districtHeld = 0,
    this.districtBonus = 0,
    this.generals = const [],
    this.generalCost = 0,
    this.generalPower = 0,
    required this.bounty,
    required this.landIncome,
    required this.prestige,
    required this.prestigeMultiplier,
    required this.canPrestige,
    required this.chapter,
  });

  final String name;
  final int money;
  final int uy;
  final RankInfo rank;
  final RankInfo? nextRank;
  final double rate;
  final int power;
  final WeaponInfo weapon;
  final WeaponInfo? nextWeapon;
  final int rosterCost;
  final int crew;
  final int crewCost;
  final int ownedCount;
  final double territoryMul;
  final List<WeaponInfo> weapons;
  final List<BusinessInfo> businesses;
  final List<Mission> missions;
  final List<CrewSkill> crewSkills;
  final Map<String, String> gangFlags;
  final int level;
  final int xp;
  final int xpNext;
  final int points;
  final int statHp;
  final int statDmg;
  final int statArmor;
  final List<Mission> daily;
  final int dailyResetAt;
  final String gangId;
  final String gangName;
  final int gangMembers;
  final double gangBonus;
  final int maxOwned;
  final int unread;
  final ContractInfo? contract;
  final int casinoLeft;
  final String seasonKey;
  final int seasonUy;
  final List<String> items;
  final String playerId;
  final int heat;
  final double heatPenalty;
  final int bribeCost;
  final String formation;
  final List<GuardSlot> guards;
  int get guardsTotal => guards.fold(0, (a, g) => a + g.count);
  final int availableCrew;
  final int guardedMinions;
  final int availableMinions;
  final int minions;
  final int minionHealthy;
  final int wounds;
  final int minionPower;
  final int minionRecruitCost;
  final int minionHealCost;
  final int maxMinions;
  final List<MinionGearInfo> minionGear;
  final double upkeep;
  final double goods;
  final double goodsRate;
  final double goodsUpkeep;
  final List<CityInfo> cities;
  final List<WorkInfo> works;
  final int districtHeld;
  final double districtBonus;
  final List<GeneralInfo> generals;
  final int generalCost;
  final int generalPower;
  final int bounty;
  final double landIncome;
  final int prestige;
  final double prestigeMultiplier;
  final bool canPrestige;
  final int chapter;

  double get expRatio => xpNext <= 0 ? 1 : (xp / xpNext).clamp(0.0, 1.0);
  int get bonusHp => statHp * 25;
  int get bonusDmg => statDmg * 3;
  double get damageReduction =>
      (statArmor * 0.02).clamp(0.0, 0.5);

  factory PlayerState.fromJson(Map<String, dynamic> j) => PlayerState(
        name: j['name'] as String? ?? '',
        money: asInt(j['money']),
        uy: asInt(j['uy']),
        rank: RankInfo.fromJson((j['rank'] as Map?)?.cast<String, dynamic>() ?? {}),
        nextRank: j['nextRank'] == null
            ? null
            : RankInfo.fromJson((j['nextRank'] as Map).cast<String, dynamic>()),
        rate: asDouble(j['rate']),
        power: asInt(j['power']),
        weapon: WeaponInfo.fromJson(
            (j['weapon'] as Map?)?.cast<String, dynamic>() ?? {}),
        nextWeapon: j['nextWeapon'] == null
            ? null
            : WeaponInfo.fromJson((j['nextWeapon'] as Map).cast<String, dynamic>()),
        rosterCost: asInt(j['rosterCost']),
        crew: asInt(j['crew']),
        crewCost: asInt(j['crewCost']),
        ownedCount: asInt(j['ownedCount']),
        territoryMul: asDouble(j['territoryMul']),
        weapons: (j['weapons'] as List? ?? [])
            .map((e) => WeaponInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        businesses: (j['businesses'] as List? ?? [])
            .map((e) => BusinessInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        missions: (j['missions'] as List? ?? [])
            .map((e) => Mission.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        crewSkills: (j['crewSkills'] as List? ?? [])
            .map((e) => CrewSkill.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        gangFlags: (j['gangFlags'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, v as String)),
        level: j['level'] == null ? 1 : asInt(j['level']),
        xp: asInt(j['xp']),
        xpNext: asInt(j['xpNext']),
        points: asInt(j['points']),
        statHp: _stat(j, 'hp'),
        statDmg: _stat(j, 'dmg'),
        statArmor: _stat(j, 'armor'),
        daily: (j['daily'] as List? ?? [])
            .map((e) => Mission.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        dailyResetAt: asInt(j['dailyResetAt']),
        gangId: j['gangId'] as String? ?? '',
        gangName: j['gangName'] as String? ?? '',
        gangMembers: asInt(j['gangMembers']),
        gangBonus: asDouble(j['gangBonus']) == 0 ? 1 : asDouble(j['gangBonus']),
        maxOwned: asInt(j['maxOwned']),
        unread: asInt(j['unread']),
        contract: j['contract'] == null
            ? null
            : ContractInfo.fromJson(
                (j['contract'] as Map).cast<String, dynamic>()),
        casinoLeft: asInt(j['casinoLeft']),
        seasonKey: j['seasonKey'] as String? ?? '',
        seasonUy: asInt(j['seasonUy']),
        items: (j['items'] as List? ?? []).map((e) => e.toString()).toList(),
        playerId: j['playerId'] as String? ?? '',
        heat: asInt(j['heat']),
        heatPenalty: asDouble(j['heatPenalty']),
        bribeCost: asInt(j['bribeCost']),
        formation: j['formation'] as String? ?? 'balanced',
        guards: (j['guards'] as List? ?? [])
            .map((e) => GuardSlot.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        guardedMinions: asInt(j['guardedMinions']),
        availableMinions: asInt(j['availableMinions']),
        availableCrew: asInt(j['availableCrew']),
        minions: asInt(j['minions']),
        minionHealthy: asInt(j['minionHealthy']),
        wounds: asInt(j['wounds']),
        minionPower: asInt(j['minionPower']),
        minionRecruitCost: asInt(j['minionRecruitCost']),
        minionHealCost: asInt(j['minionHealCost']),
        maxMinions: asInt(j['maxMinions']),
        minionGear: (j['minionGear'] as List? ?? [])
            .map((e) => MinionGearInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        upkeep: asDouble(j['upkeep']),
        goods: asDouble(j['goods']),
        goodsRate: asDouble(j['goodsRate']),
        goodsUpkeep: asDouble(j['goodsUpkeep']),
        cities: (j['cities'] as List? ?? [])
            .map((e) => CityInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        works: (j['works'] as List? ?? [])
            .map((e) => WorkInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        districtHeld: asInt(j['districtHeld']),
        districtBonus: asDouble(j['districtBonus']),
        generals: (j['generals'] as List? ?? [])
            .map((e) => GeneralInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        generalCost: asInt(j['generalCost']),
        generalPower: asInt(j['generalPower']),
        bounty: asInt(j['bounty']),
        landIncome: asDouble(j['landIncome']),
        prestige: asInt(j['prestige']),
        prestigeMultiplier: asDouble(j['prestigeMultiplier']) == 0
            ? 1
            : asDouble(j['prestigeMultiplier']),
        canPrestige: j['canPrestige'] as bool? ?? false,
        chapter: asInt(j['chapter']),
      );

  double get rankProgress {
    final next = nextRank;
    if (next == null) return 1;
    final base = rank.uy;
    final span = next.uy - base;
    if (span <= 0) return 1;
    return ((uy - base) / span).clamp(0.0, 1.0);
  }
}

int _stat(Map<String, dynamic> j, String key) {
  final stats = (j['stats'] as Map?)?.cast<String, dynamic>();
  return stats == null ? 0 : asInt(stats[key]);
}

class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.tax,
    required this.defense,
    required this.ownerGangId,
    required this.level,
    this.prevOwnerId = '',
    this.contestedUntil = 0,
    this.provinceId = 0,
    this.province = '',
    this.region = 0,
  });

  final int id;
  final String name;
  final String ownerId;
  final String ownerName;
  final int tax;
  final int defense;
  final String ownerGangId;
  final int level;
  final String prevOwnerId;
  final int contestedUntil;
  final int provinceId;
  final String province;
  final int region;

  bool get contested =>
      contestedUntil > DateTime.now().millisecondsSinceEpoch ~/ 1000;

  int get upgradeCost => 600 * (level + 1) * (level + 1);

  bool get isNeutral => ownerId.isEmpty;
  bool get isMine => ownerId.startsWith('p:');

  /// Tên đầy đủ kèm tỉnh — tỉnh nào cũng có Quận 1..12, gọi trần "Quận 1" thì
  /// không phân biệt được ô nào.
  String get fullName => province.isEmpty ? name : '$province · $name';

  factory Territory.fromJson(Map<String, dynamic> j) => Territory(
        id: asInt(j['id']),
        name: j['name'] as String? ?? '',
        ownerId: j['ownerId'] as String? ?? '',
        ownerName: j['ownerName'] as String? ?? '',
        tax: asInt(j['tax']),
        defense: asInt(j['defense']),
        ownerGangId: j['ownerGangId'] as String? ?? '',
        level: asInt(j['level']),
        prevOwnerId: j['prevOwnerId'] as String? ?? '',
        contestedUntil: asInt(j['contestedUntil']),
        provinceId: asInt(j['provinceId']),
        province: j['province'] as String? ?? '',
        region: asInt(j['region']),
      );
}

class FightEvent {
  const FightEvent({
    required this.at,
    required this.side,
    required this.crit,
    required this.miss,
    required this.dmg,
    required this.myHp,
    required this.enemyHp,
  });

  final int at;
  final String side;
  final bool crit;
  final bool miss;
  final int dmg;
  final int myHp;
  final int enemyHp;

  factory FightEvent.fromJson(Map<String, dynamic> j) => FightEvent(
        at: asInt(j['at']),
        side: j['side'] as String? ?? 'me',
        crit: j['crit'] as bool? ?? false,
        miss: j['miss'] as bool? ?? false,
        dmg: asInt(j['dmg']),
        myHp: asInt(j['myHp']),
        enemyHp: asInt(j['enemyHp']),
      );
}

class BrawlResult {
  const BrawlResult({
    required this.win,
    required this.events,
    required this.reward,
    required this.uyGain,
    required this.power,
    required this.defense,
    this.wounded = 0,
    required this.territoryId,
    required this.territoryName,
    this.territoryProvince = '',
    required this.xp,
    required this.levelups,
    required this.levelupMoney,
    required this.bounty,
    required this.landIncome,
    required this.prestige,
    required this.prestigeMultiplier,
    required this.canPrestige,
    required this.chapter,
  });

  final bool win;
  final List<FightEvent> events;
  final int reward;
  final int uyGain;
  final int power;
  final int defense;
  final int wounded;
  final int territoryId;
  final String territoryName;
  final String territoryProvince;
  final int xp;
  final int levelups;
  final int levelupMoney;
  final int bounty;
  final double landIncome;
  final int prestige;
  final double prestigeMultiplier;
  final bool canPrestige;
  final int chapter;

  /// "Đồng Nai · Quận 1" — tỉnh nào cũng có Quận 1..12 nên tên trần là mơ hồ.
  String get territoryLabel => territoryProvince.isEmpty
      ? territoryName
      : '$territoryProvince · $territoryName';

  factory BrawlResult.fromJson(Map<String, dynamic> j) => BrawlResult(
        win: j['win'] as bool? ?? false,
        events: (j['events'] as List? ?? [])
            .map((e) => FightEvent.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        reward: asInt(j['reward']),
        uyGain: asInt(j['uyGain']),
        power: asInt(j['power']),
        defense: asInt(j['defense']),
        wounded: asInt(j['wounded']),
        territoryId: asInt(j['territoryId']),
        territoryName: j['territoryName'] as String? ?? '',
        territoryProvince: j['territoryProvince'] as String? ?? '',
        xp: asInt(j['xp']),
        levelups: asInt(j['levelups']),
        levelupMoney: asInt(j['levelupMoney']),
        bounty: asInt(j['bounty']),
        landIncome: asDouble(j['landIncome']),
        prestige: asInt(j['prestige']),
        prestigeMultiplier: asDouble(j['prestigeMultiplier']) == 0
            ? 1
            : asDouble(j['prestigeMultiplier']),
        canPrestige: j['canPrestige'] as bool? ?? false,
        chapter: asInt(j['chapter']),
      );
}

class RankingRow {
  const RankingRow({
    required this.id,
    required this.name,
    required this.rank,
    required this.uy,
    required this.power,
    required this.owned,
    required this.isMe,
    required this.bounty,
    required this.gangFlag,
    required this.landIncome,
    required this.prestige,
    required this.prestigeMultiplier,
    required this.canPrestige,
    required this.chapter,
  });

  final String id;
  final String name;
  final String rank;
  final int uy;
  final int power;
  final int owned;
  final bool isMe;
  final int bounty;
  final String gangFlag;
  final double landIncome;
  final int prestige;
  final double prestigeMultiplier;
  final bool canPrestige;
  final int chapter;

  factory RankingRow.fromJson(Map<String, dynamic> j) => RankingRow(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        rank: j['rank'] as String? ?? '',
        uy: asInt(j['uy']),
        power: asInt(j['power']),
        owned: asInt(j['owned']),
        isMe: j['isMe'] as bool? ?? false,
        bounty: asInt(j['bounty']),
        gangFlag: j['gangFlag'] as String? ?? '',
        landIncome: asDouble(j['landIncome']),
        prestige: asInt(j['prestige']),
        prestigeMultiplier: asDouble(j['prestigeMultiplier']) == 0
            ? 1
            : asDouble(j['prestigeMultiplier']),
        canPrestige: j['canPrestige'] as bool? ?? false,
        chapter: asInt(j['chapter']),
      );
}

String formatMoney(num v) {
  final n = v.toDouble();
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}Tỷ';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}Tr';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}
