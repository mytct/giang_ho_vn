import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../scene/alley_game.dart';
import '../theme.dart';
import '../widgets/boss_avatar.dart';
import '../widgets/common.dart';
import 'event_sheets.dart';
import 'brawl_screen.dart';
import 'level_sheet.dart';
import 'vn_map_data.dart';

const _rankColors = [
  Color(0xFF8A90A0),
  GH.cyan,
  GH.green,
  GH.gold,
  GH.pink,
  Color(0xFFFF7A00),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AlleyGame _scene;
  int _region = homeRegionIndex;

  @override
  void initState() {
    super.initState();
    _scene = AlleyGame(rate: widget.controller.state?.rate ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.state;
        if (s == null) {
          return const Center(child: CircularProgressIndicator(color: GH.pink));
        }
        _scene.setRate(s.rate);
        final regions = _ownedRegions(s);
        final region = regions.contains(_region) ? _region : homeRegionIndex;
        return Column(
          children: [
            _PlayerHeader(state: s, controller: c),
            if (s.heat > 0) _HeatBar(state: s, controller: c),
            SizedBox(
              height: 310,
              width: double.infinity,
              child: ClipRect(child: GameWidget(game: _scene)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _MissionCard(state: s, onTap: _openMissions),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.assignment_turned_in_rounded,
                            label: 'Hợp đồng',
                            sub: s.contract == null ? '3 kèo' : 'đang chạy',
                            color: GH.gold,
                            onTap: () => showContractsSheet(context, c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.casino_rounded,
                            label: 'Sòng bạc',
                            sub: '${s.casinoLeft} lượt',
                            color: GH.pink,
                            onTap: () => showCasinoSheet(context, c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.whatshot_rounded,
                            label: 'Boss tuần',
                            sub: 'góp dmg',
                            color: GH.red,
                            onTap: () => showBossSheet(context, c),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CampaignStrip(
                    state: s,
                    chapters: c.chapters,
                    onTap: _openCampaign,
                  ),
                  SectionTitle(
                    text: 'Cơ sở làm ăn',
                    trailing: Text(
                      '${s.businesses.where((b) => b.region == region && b.unlocked).length}'
                      '/${s.businesses.where((b) => b.region == region).length} mở khoá',
                      style: labelStyle(size: 10.5),
                    ),
                  ),
                  _regionChips(s, regions),
                  const SizedBox(height: 6),
                  for (final b in s.businesses.where((b) => b.region == region))
                    _BusinessTile(
                      business: b,
                      onTap: () {
                        if (!b.unlocked) {
                          showToast(
                            context,
                            'Cần đạt ${b.unlockName} mới mở được',
                            error: true,
                          );
                          return;
                        }
                        if (!b.land) {
                          showToast(
                            context,
                            'Giữ ít nhất 1 ô ở khu này mới làm ăn được',
                            error: true,
                          );
                          return;
                        }
                        _openUpgradeSheet(b);
                      },
                    ),
                  _PrestigeCard(state: s, controller: c),
                  const _TipCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCampaign() async {
    final c = widget.controller;
    if (c.chapters.isEmpty) {
      try {
        await c.loadCampaign();
      } on ApiException catch (e) {
        if (mounted) showToast(context, e.message, error: true);
        return;
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          final s = c.state;
          if (s == null) return const SizedBox.shrink();
          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.82,
            decoration: const BoxDecoration(
              color: GH.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: GH.line)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GH.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
                    child: Row(
                      children: [
                        const Text(
                          'CỐT TRUYỆN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: GH.muted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: c.chapters.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ChapterTile(
                        chapter: c.chapters[i],
                        state: s,
                        busy: c.busy,
                        onFight: () => _fightChapter(ctx, c.chapters[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fightChapter(BuildContext ctx, Chapter ch) async {
    final nav = Navigator.of(ctx);
    final c = widget.controller;
    try {
      final result = await c.fightChapter(ch.id);
      final s = c.state;
      if (s == null) return;
      nav.pop();
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => BrawlScreen(
            result: result,
            playerName: s.name,
            myCount: (s.crew + 1).clamp(1, 5),
            myWeapon: s.weapon.name,
            enemyName: ch.bossName,
            bossChapter: ch.id,
          ),
        ),
      );
      if (nav.mounted) {
        showToast(
          nav.context,
          result.win
              ? 'Hạ ${ch.bossName}, mở chương tiếp theo'
              : 'Thua ${ch.bossName}, luyện thêm rồi quay lại',
        );
      }
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }

  void _openMissions() {
    final c = widget.controller;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          final s = c.state;
          if (s == null) return const SizedBox.shrink();
          final claimed = s.missions.where((m) => m.claimed).length;
          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.8,
            decoration: const BoxDecoration(
              color: GH.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: GH.line)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GH.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
                    child: Row(
                      children: [
                        const Text(
                          'NHIỆM VỤ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$claimed/${s.missions.length} xong',
                          style: labelStyle(size: 11),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: GH.muted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      children: [
                        Row(
                          children: [
                            Text(
                              'HÔM NAY',
                              style: labelStyle(size: 10.5, color: GH.cyan),
                            ),
                            const Spacer(),
                            Text(
                              'reset 00:00 mỗi ngày',
                              style: labelStyle(size: 9.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final m in s.daily)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MissionTile(
                              mission: m,
                              busy: c.busy,
                              onClaim: () => _claimDaily(ctx, m),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'MỘT LẦN',
                          style: labelStyle(size: 10.5, color: GH.pink),
                        ),
                        const SizedBox(height: 8),
                        for (final m in s.missions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MissionTile(
                              mission: m,
                              busy: c.busy,
                              onClaim: () => _claimMission(ctx, m),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _claimDaily(BuildContext ctx, Mission mission) async {
    try {
      await widget.controller.claimDaily(mission.id);
      if (ctx.mounted) {
        showToast(
          ctx,
          'Nhận thưởng ngày: +${formatMoney(mission.rewardMoney)}đ · +${mission.rewardUy} uy',
        );
      }
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }

  Future<void> _claimMission(BuildContext ctx, Mission mission) async {
    try {
      await widget.controller.claimMission(mission.id);
      if (ctx.mounted) {
        showToast(
          ctx,
          'Nhận thưởng: +${formatMoney(mission.rewardMoney)}đ · +${mission.rewardUy} uy',
        );
      }
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }

  String _regionName(int region) => region >= 0 && region < vnRegionNames.length
      ? vnRegionNames[region]
      : 'Vùng $region';

  int _regionHeld(PlayerState s, int region) {
    var n = 0;
    for (final c in s.cities) {
      if (c.region == region) n += c.held;
    }
    return n;
  }

  List<int> _ownedRegions(PlayerState s) => [
        for (var i = 0; i < vnRegionNames.length; i++)
          if (i == homeRegionIndex || _regionHeld(s, i) > 0) i,
      ];

  Widget _regionChips(PlayerState s, List<int> regions) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: regions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final i = regions[idx];
          final active = _region == i;
          final held = _regionHeld(s, i);
          final open = held > 0 || i == homeRegionIndex;
          return GestureDetector(
            onTap: () => setState(() => _region = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? GH.cyan.withValues(alpha: 0.16) : GH.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? GH.cyan : GH.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!open) ...[
                    const Icon(Icons.lock_rounded, size: 11, color: GH.muted),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _regionName(i),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: active ? GH.cyan : GH.text,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('$held quận', style: labelStyle(size: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openUpgradeSheet(BusinessInfo b) {
    final c = widget.controller;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          final s = c.state;
          if (s == null) return const SizedBox.shrink();
          final biz = s.businesses.firstWhere(
            (e) => e.id == b.id && e.region == b.region,
            orElse: () => b,
          );
          final nextRate = biz.level == 0
              ? 0.0
              : biz.rate / biz.level * (biz.level + 1);
          final canBuy = s.money >= biz.upgradeCost && !c.busy && biz.land;
          return Container(
            decoration: const BoxDecoration(
              color: GH.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: GH.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: GH.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _BizIcon(text: biz.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                biz.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Cấp ${biz.level}',
                                style: labelStyle(size: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${formatMoney(biz.rate)}/s',
                          style: moneyStyle(size: 16, color: GH.cyan),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _kv('Vùng', _regionName(biz.region), color: GH.cyan),
                    _kv('Thu nhập hiện tại', '+${formatMoney(biz.rate)}/s'),
                    _kv(
                      'Sau nâng cấp',
                      '+${formatMoney(nextRate)}/s',
                      color: GH.green,
                    ),
                    _kv('Chi phí', '${formatMoney(biz.upgradeCost)} đ'),
                    _kv(
                      'Bảo kê',
                      '${biz.racket}/3 (+${biz.racket * 15}% thu nhập)',
                      color: GH.pink,
                    ),
                    if (biz.racket < 3)
                      _kv(
                        'Dằn mặt thêm',
                        '${formatMoney(biz.racketCost)} đ · +15% · +5 nóng',
                        color: GH.muted,
                      ),
                    _kv(
                      'Mày đang có',
                      '${formatMoney(s.money)} đ',
                      color: GH.gold,
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: !biz.land
                          ? 'CẦN GIỮ ĐẤT Ở KHU NÀY'
                          : canBuy
                              ? 'NÂNG CẤP  −${formatMoney(biz.upgradeCost)}'
                              : (c.busy ? 'ĐANG XỬ LÝ...' : 'KHÔNG ĐỦ TIỀN'),
                      icon: Icons.trending_up_rounded,
                      enabled: canBuy,
                      onTap: () => _doUpgrade(ctx, biz.id, biz.region),
                    ),
                    if (biz.racket < 3) ...[
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: s.money >= biz.racketCost && !c.busy
                            ? 'DẰN MẶT  −${formatMoney(biz.racketCost)}'
                            : (c.busy
                                ? 'ĐANG XỬ LÝ...'
                                : 'KHÔNG ĐỦ TIỀN DẰN MẶT'),
                        icon: Icons.local_fire_department_rounded,
                        color: GH.pink,
                        enabled: s.money >= biz.racketCost && !c.busy,
                        onTap: () => _doRacket(ctx, biz.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _doRacket(BuildContext ctx, String id) async {
    try {
      await widget.controller.raiseRacket(id);
      if (ctx.mounted) showToast(ctx, 'Đã dằn mặt: +15% thu nhập, +5 độ nóng');
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }

  Future<void> _doUpgrade(BuildContext ctx, String id, int district) async {
    try {
      await widget.controller.upgrade(id, district);
      if (ctx.mounted) Navigator.of(ctx).pop();
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.state, required this.controller});

  final PlayerState state;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final rankColor =
        _rankColors[state.rank.level.clamp(0, _rankColors.length - 1)];
    final next = state.nextRank;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor.withValues(alpha: 0.14),
                  border: Border.all(color: rankColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Text(
                  '${state.rank.level + 1}',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.rank.name} · Uy ${formatMoney(state.uy)}',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showInboxSheet(context, controller),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: Badge(
                  isLabelVisible: state.unread > 0,
                  label: Text(
                    '${state.unread}',
                    style: const TextStyle(fontSize: 9),
                  ),
                  backgroundColor: GH.red,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 21,
                    color: state.unread > 0 ? GH.text : GH.muted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(state.money), style: moneyStyle(size: 21)),
                  Text(
                    '+${formatMoney(state.rate)}/s',
                    style: const TextStyle(
                      color: GH.cyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (state.upkeep > 0)
                    Text(
                      '−${formatMoney(state.upkeep)}/s lương',
                      style: TextStyle(
                        color: state.upkeep >= state.rate ? GH.red : GH.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    'Hàng ${state.goods.round()} · ${state.goodsRate.toStringAsFixed(1)}/s',
                    style: TextStyle(
                      color: state.goodsUpkeep > state.goodsRate
                          ? GH.red
                          : GH.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showLevelSheet(context, controller),
            child: Row(
              children: [
                Text(
                  'Lv ${state.level}',
                  style: const TextStyle(
                    color: GH.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: state.expRatio,
                      minHeight: 4,
                      backgroundColor: GH.line,
                      valueColor: const AlwaysStoppedAnimation(GH.cyan),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${state.xp}/${state.xpNext} EXP',
                  style: labelStyle(size: 9.5),
                ),
                if (state.points > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: GH.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '+${state.points} điểm',
                      style: labelStyle(size: 9, color: GH.gold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.rankProgress,
              minHeight: 5,
              backgroundColor: GH.line,
              valueColor: const AlwaysStoppedAnimation(GH.pink),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  next != null
                      ? 'Còn ${formatMoney(next.uy - state.uy)} uy lên ${next.name}'
                      : 'Bậc cao nhất rồi, đại ca',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle(
                    size: 10.5,
                    color: next == null ? GH.gold : GH.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'x${state.territoryMul.toStringAsFixed(1)} địa bàn',
                style: labelStyle(size: 10.5, color: GH.cyan),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: GH.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GH.line),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: StatChip(
                    icon: Icons.fitness_center_rounded,
                    value: '${state.power}',
                    label: 'lực',
                    color: GH.pink,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: StatChip(
                    icon: Icons.groups_rounded,
                    value: '${state.crew}',
                    label: 'quân',
                    color: GH.cyan,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: StatChip(
                    icon: Icons.flag_rounded,
                    value: '${state.ownedCount}',
                    label: 'ô',
                    color: GH.gold,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: StatChip(
                    icon: Icons.gavel_rounded,
                    value: '${state.weapon.dmg}',
                    label: 'dmg',
                    color: GH.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: NeonPanel(
        color: GH.bg2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: GH.gold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mỗi ô địa bàn chiếm được cộng 10% thu nhập. Rảnh thì qua tab Bản đồ kiếm vài ô.',
                style: labelStyle(size: 11, color: GH.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({required this.business, required this.onTap});

  final BusinessInfo business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !business.unlocked || !business.land;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: NeonPanel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _BizIcon(text: business.icon, locked: locked),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked
                            ? (business.unlocked
                                ? 'Chưa giữ ô nào ở khu này'
                                : 'Cần đạt ${business.unlockName}')
                            : 'Cấp ${business.level} · +${formatMoney(business.rate)}/s'
                                '${business.racket > 0 ? ' · BK ${business.racket}/3' : ''}',
                        style: labelStyle(
                          size: 11,
                          color: locked ? GH.muted : GH.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  const Icon(Icons.lock_rounded, size: 18, color: GH.muted)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatMoney(business.upgradeCost)} đ',
                        style: moneyStyle(size: 12, color: GH.gold),
                      ),
                      const SizedBox(height: 2),
                      Text('nâng cấp', style: labelStyle(size: 9.5)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BizIcon extends StatelessWidget {
  const _BizIcon({required this.text, this.locked = false});

  final String text;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: locked
              ? [GH.panel2, GH.panel]
              : [GH.pink.withValues(alpha: 0.28), GH.panel2],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: locked ? GH.line : GH.pink.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: locked ? GH.muted : GH.text,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Widget _kv(String label, String value, {Color color = GH.text}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: labelStyle(size: 12.5)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.state, required this.onTap});

  final PlayerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final all = [...state.daily, ...state.missions];
    final total = all.length;
    final claimed = all.where((m) => m.claimed).length;
    final ready = all.where((m) => m.claimable).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: NeonPanel(
          borderColor: ready > 0 ? GH.gold.withValues(alpha: 0.6) : GH.line,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GH.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GH.gold.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_rounded,
                      color: GH.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NHIỆM VỤ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          ready > 0
                              ? '$claimed/$total xong · $ready phần thưởng chờ nhận'
                              : '$claimed/$total xong · làm tiếp đi đại ca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle(
                            size: 10.5,
                            color: ready > 0 ? GH.gold : GH.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ready > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GH.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NHẬN $ready',
                        style: labelStyle(size: 9.5, color: GH.gold),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: GH.muted,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : claimed / total,
                  minHeight: 4,
                  backgroundColor: GH.line,
                  valueColor: const AlwaysStoppedAnimation(GH.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.busy,
    required this.onClaim,
  });

  final Mission mission;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final shown = m.progress.clamp(0, m.target);
    return NeonPanel(
      color: m.claimable ? const Color(0xFF1B1710) : GH.panel,
      borderColor: m.claimable ? GH.gold.withValues(alpha: 0.55) : GH.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                m.claimed
                    ? Icons.check_circle_rounded
                    : (m.claimable
                          ? Icons.workspace_premium_rounded
                          : Icons.radio_button_unchecked_rounded),
                size: 17,
                color: m.claimed
                    ? GH.green
                    : (m.claimable ? GH.gold : GH.muted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$shown/${m.target}',
                style: labelStyle(
                  size: 10.5,
                  color: m.done ? GH.green : GH.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(m.desc, style: labelStyle(size: 10.5)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: m.ratio,
              minHeight: 4,
              backgroundColor: GH.line,
              valueColor: AlwaysStoppedAnimation(
                m.claimed ? GH.green : GH.gold,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 13, color: GH.gold),
              const SizedBox(width: 4),
              Text(
                '+${formatMoney(m.rewardMoney)}',
                style: moneyStyle(size: 12),
              ),
              const SizedBox(width: 10),
              Icon(Icons.military_tech_rounded, size: 13, color: GH.cyan),
              const SizedBox(width: 4),
              Text(
                '+${m.rewardUy} uy',
                style: const TextStyle(
                  color: GH.cyan,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (m.claimable)
                SizedBox(
                  width: 86,
                  child: PrimaryButton(
                    label: 'NHẬN',
                    height: 32,
                    color: GH.gold,
                    enabled: !busy,
                    onTap: onClaim,
                  ),
                )
              else if (m.claimed)
                Text('ĐÃ NHẬN', style: labelStyle(size: 9.5, color: GH.green))
              else
                Text('ĐANG LÀM', style: labelStyle(size: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle(size: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatBar extends StatelessWidget {
  const _HeatBar({required this.state, required this.controller});

  final PlayerState state;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final hot = state.heat >= 80;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GH.red.withValues(alpha: hot ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GH.red.withValues(alpha: hot ? 0.6 : 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_police_rounded, size: 15, color: GH.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hot
                    ? 'Độ nóng ${state.heat} · cớm đang để ý, không chém được'
                    : 'Độ nóng ${state.heat} · thu nhập −${(state.heatPenalty * 100).round()}%',
                maxLines: 2,
                style: labelStyle(size: 9.5, color: hot ? GH.red : GH.muted),
              ),
            ),
            GestureDetector(
              onTap: () => _bribe(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GH.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ĐÚT ${formatMoney(state.bribeCost)}',
                  style: labelStyle(size: 9, color: GH.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bribe(BuildContext context) async {
    try {
      await controller.bribeHeat();
      if (context.mounted) showToast(context, 'Đã đút lót, nguội rồi');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}

class _CampaignStrip extends StatelessWidget {
  const _CampaignStrip({
    required this.state,
    required this.chapters,
    required this.onTap,
  });

  final PlayerState state;
  final List<Chapter> chapters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Chapter? current;
    for (final c in chapters) {
      if (c.status == 'current') current = c;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: NeonPanel(
          borderColor: GH.cyan.withValues(alpha: 0.3),
          child: Row(
            children: [
              BossAvatar(
                chapterId: current?.id ?? chapters.length - 1,
                size: 38,
                borderColor: GH.cyan.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current == null
                          ? 'CỐT TRUYỆN · HOÀN THÀNH'
                          : 'CỐT TRUYỆN · CHƯƠNG ${current.id + 1}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      current == null
                          ? 'Đã phá hết 6 quận'
                          : '${current.title} · ${current.desc}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle(size: 9.5),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: GH.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.state,
    required this.busy,
    required this.onFight,
  });

  final Chapter chapter;
  final PlayerState state;
  final bool busy;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    final ch = chapter;
    final current = ch.status == 'current';
    final cleared = ch.status == 'cleared';
    final canFight =
        current &&
        state.ownedCount >= ch.needOwned &&
        state.uy >= ch.needUy &&
        !busy;
    return NeonPanel(
      color: current ? const Color(0xFF101A19) : GH.bg2,
      borderColor: current
          ? GH.cyan.withValues(alpha: 0.45)
          : (cleared ? GH.green.withValues(alpha: 0.3) : GH.line),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BossAvatar(
            chapterId: ch.id,
            size: 64,
            dimmed: !current && !cleared,
            borderColor: current
                ? GH.cyan.withValues(alpha: 0.5)
                : (cleared ? GH.green.withValues(alpha: 0.4) : GH.line),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CHƯƠNG ${ch.id + 1}',
                      style: labelStyle(size: 9, color: GH.cyan),
                    ),
                    const Spacer(),
                    Text(
                      cleared ? 'ĐÃ QUA' : (current ? 'ĐANG MỞ' : 'CHƯA MỞ'),
                      style: labelStyle(
                        size: 8.5,
                        color: cleared
                            ? GH.green
                            : (current ? GH.gold : GH.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ch.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${ch.desc} · Trùm: ${ch.bossName} (${ch.bossPower} lực)',
                  style: labelStyle(size: 9.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Cần ${ch.needOwned} ô · ${formatMoney(ch.needUy)} uy',
                      style: labelStyle(
                        size: 9,
                        color:
                            current &&
                                (state.ownedCount < ch.needOwned ||
                                    state.uy < ch.needUy)
                            ? GH.red
                            : GH.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '+${formatMoney(ch.rewardMoney)} · +${ch.rewardUy} uy',
                      style: labelStyle(size: 9, color: GH.gold),
                    ),
                  ],
                ),
                if (current) ...[
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: canFight ? 'ĐÁNH TRÙM' : 'CHƯA ĐỦ ĐIỀU KIỆN',
                    icon: Icons.sports_mma_rounded,
                    height: 34,
                    color: GH.cyan,
                    enabled: canFight,
                    onTap: onFight,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrestigeCard extends StatelessWidget {
  const _PrestigeCard({required this.state, required this.controller});

  final PlayerState state;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: NeonPanel(
        borderColor: state.canPrestige
            ? GH.gold.withValues(alpha: 0.55)
            : GH.line,
        color: state.canPrestige ? const Color(0xFF1B1710) : GH.bg2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restart_alt_rounded, color: GH.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MÁU GIANG HỒ x${state.prestigeMultiplier.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (state.prestige > 0)
                  Text(
                    'RA TÙ ${state.prestige} LẦN',
                    style: labelStyle(size: 9, color: GH.gold),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.canPrestige
                  ? 'Đủ 15.000 uy. Ra tù: reset tiền/cơ sở/địa bàn/quân, giữ đồ sưu tập và tăng vĩnh viễn 10% thu nhập + lực.'
                  : 'Cần 15.000 uy để ra tù (hiện ${formatMoney(state.uy)}). Reset để nhận multiplier vĩnh viễn.',
              style: labelStyle(size: 9.5),
            ),
            if (state.canPrestige) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'RA TÙ',
                icon: Icons.exit_to_app_rounded,
                height: 34,
                color: GH.gold,
                enabled: !controller.busy,
                onTap: () => _confirmPrestige(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPrestige(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GH.panel,
        title: const Text('Ra tù?'),
        content: Text(
          'Mất hết tiền, cơ sở, địa bàn, quân và cấp. Đổi lại +10% thu nhập và lực vĩnh viễn.',
          style: labelStyle(size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ở LẠI', style: labelStyle(size: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('RA TÙ', style: labelStyle(size: 12, color: GH.gold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.prestige();
      if (context.mounted) {
        showToast(context, 'Ra tù xong, máu giang hồ tăng');
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}
