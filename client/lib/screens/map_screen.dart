import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pixel_flag.dart';
import 'brawl_screen.dart';
import 'rpg_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.state;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text(
                    'BẢN ĐỒ',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 8),
                  if (s != null)
                    Text('${s.ownedCount}/${s.maxOwned} ô',
                        style: labelStyle(size: 11)),
                  if (s != null && s.districtHeld > 0)
                    Text(
                      ' · ${s.districtHeld} thành +${(s.districtBonus * 100).round()}%',
                      style: labelStyle(size: 11, color: GH.gold),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        c.loadMap().catchError((Object _) {}),
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: GH.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      // Bấm legend mở danh sách ĐẦY ĐỦ các chủ đất.
                      onTap: () => _showLegendSheet(context),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _legend(GH.muted, 'Trống'),
                            for (final row in _gangLegend())
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: _legend(row.$1, row.$2),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.expand_more_rounded,
                                  size: 14, color: GH.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (s != null)
                    Text('Lực ${s.power}',
                        style: labelStyle(size: 11, color: GH.pink)),
                ],
              ),
            ),
            // Độ nóng chạm ngưỡng thì server chặn chém — báo trước ở đây.
            if (s != null && s.heat >= 80)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 12, color: GH.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'NÓNG ${s.heat}° — không chém được, đút lót ở Sân trước',
                        style: labelStyle(size: 9.5, color: GH.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: c.territories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.mapError) ...[
                            Text('Không lấy được bản đồ từ server',
                                style: labelStyle(size: 12)),
                            const SizedBox(height: 10),
                            PrimaryButton(
                              label: 'THỬ LẠI',
                              icon: Icons.refresh_rounded,
                              color: GH.cyan,
                              height: 38,
                              onTap: () => c.loadMap().catchError((Object _) {}),
                            ),
                          ] else ...[
                            const CircularProgressIndicator(color: GH.pink),
                            const SizedBox(height: 12),
                            Text('Đang lấy bản đồ...',
                                style: labelStyle(size: 12)),
                          ],
                        ],
                      ),
                    )
                  : RpgMapView(
                      territories: c.territories,
                      myId: s?.playerId ?? '',
                      myGangId: s?.gangId ?? '',
                      guards: s == null
                          ? const <int, GuardSlot>{}
                          : {
                              for (final g in s.guards) g.territoryId: g,
                            },
                      gangFlags: s?.gangFlags ?? const <String, String>{},
                      onTapTerritory: _openTerritoryById,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: labelStyle(size: 10)),
      ],
    );
  }

  List<(Color, String)> _gangLegend() {
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final t in widget.controller.territories) {
      final key = territoryGroup(t);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () => t.ownerName);
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final s = widget.controller.state;
    return [
      for (final e in top.take(3))
        (
          gangColor(
            e.key,
            myId: s?.playerId ?? '',
            myGangId: s?.gangId ?? '',
          ),
          _shortName(names[e.key] ?? '?'),
        ),
    ];
  }

  String _shortName(String name) =>
      name.length <= 12 ? name : '${name.substring(0, 11)}…';

  static const _npcNames = {
    'npc:ran': 'Băng Rắn Độc',
    'npc:ca': 'Băng Cá Sấu',
    'npc:o': 'Băng Ó Đen',
    'npc:chuot': 'Băng Chuột Cống',
  };

  // Sheet legend đầy đủ: mọi chủ đất có trên bản đồ, sắp theo số ô.
  void _showLegendSheet(BuildContext context) {
    final c = widget.controller;
    final s = c.state;
    if (s == null) return;
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final t in c.territories) {
      final key = territoryGroup(t);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () {
        if (key.startsWith('npc:')) return _npcNames[key] ?? key;
        return t.ownerName;
      });
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: GH.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: GH.line)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.65,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  const SizedBox(height: 10),
                  Text('AI GIỮ GÌ TRÊN BẢN ĐỒ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: keys.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final key = keys[i];
                        final color =
                            gangColor(key, myId: s.playerId, myGangId: s.gangId);
                        final mine =
                            key == 'p:${s.playerId}' || key == s.gangId;
                        return NeonPanel(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          color: mine
                              ? const Color(0xFF1D1118)
                              : GH.panel,
                          borderColor: mine
                              ? GH.pink.withValues(alpha: 0.6)
                              : GH.line,
                          child: Row(
                            children: [
                              PixelFlag(gangKey: key, size: 16),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  names[key] ?? key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: mine ? GH.pink : GH.text,
                                  ),
                                ),
                              ),
                              Text('${counts[key]} ô',
                                  style: labelStyle(
                                      size: 10.5, color: GH.cyan)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTerritoryById(int id) {
    for (final t in widget.controller.territories) {
      if (t.id == id) {
        _openTerritory(t);
        return;
      }
    }
  }

  void _openTerritory(Territory t) {
    final c = widget.controller;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedBuilder(
        animation: c,
        builder: (ctx, _) {
          final s = c.state;
          if (s == null) return const SizedBox.shrink();
          final mine =
              s.playerId.isNotEmpty && t.ownerId == 'p:${s.playerId}';
          final ally = !mine &&
              s.gangId.isNotEmpty &&
              t.ownerGangId == s.gangId;
          final diff = s.power - t.defense;
          final outmatched = diff < 0;
          GuardSlot? garrison;
          if (mine) {
            for (final g in s.guards) {
              if (g.territoryId == t.id) {
                garrison = g;
                break;
              }
            }
          }
          CityInfo? city;
          for (final ci in s.cities) {
            if (ci.district == t.provinceId) {
              city = ci;
              break;
            }
          }
          return Container(
            decoration: const BoxDecoration(
              color: GH.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: GH.line)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                    Text(t.fullName,
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      mine
                          ? 'Địa bàn của mày'
                          : ally
                              ? 'Đồng minh: ${t.ownerName}'
                              : t.ownerName.isEmpty
                                  ? 'Đất trống — không chủ'
                                  : 'Chủ: ${t.ownerName}',
                      style: labelStyle(
                          size: 12,
                          color: mine
                              ? GH.pink
                              : (ally ? GH.green : GH.muted)),
                    ),
                    const SizedBox(height: 16),
                    _row('Bảo kê mỗi lượt',
                        '${formatMoney(t.tax)} đ', GH.gold),
                    _row('Cấp địa bàn', '${t.level}/5', GH.cyan),
                    _row('Phòng thủ', '${t.defense}', GH.cyan),
                    _row('Lực của mày', '${s.power}', GH.pink),
                    if (garrison != null &&
                        (garrison.count > 0 ||
                            garrison.minions > 0 ||
                            garrison.general.isNotEmpty))
                      _row(
                        'Đang giữ',
                        '${garrison.count} đàn em · ${garrison.minions} lính'
                        '${garrison.general.isEmpty ? '' : ' · ★ ${garrison.general}'}',
                        GH.cyan,
                      ),
                    if (t.contested)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          mine
                              ? 'ĐẤT CHƯA VỮNG · còn ${_clock(t.contestedUntil)} — chủ cũ đánh lại được, phòng thủ chỉ 60%'
                              : 'ĐANG TRANH CHẤP · còn ${_clock(t.contestedUntil)} — phòng thủ yếu, đánh lấy lại dễ hơn',
                          style: const TextStyle(
                            color: GH.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    NeonPanel(
                      color: outmatched
                          ? const Color(0xFF2A1218)
                          : const Color(0xFF10241C),
                      borderColor: outmatched ? GH.red : GH.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            outmatched
                                ? Icons.warning_amber_rounded
                                : Icons.trending_up_rounded,
                            size: 16,
                            color: outmatched ? GH.red : GH.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              outmatched
                                  ? 'Lực mày yếu hơn phòng thủ. Kiếm thêm quân hoặc đồ trước đã.'
                                  : 'Ngang cơ hoặc trội hơn. Ăn được.',
                              style: TextStyle(
                                color: outmatched ? GH.red : GH.green,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (city != null) _citySection(s, city, ctx, c),
                    const SizedBox(height: 16),
                    if (mine) ...[
                      PrimaryButton(
                        label: t.level >= 5
                            ? 'CẤP TỐI ĐA'
                            : 'NÂNG CẤP −${formatMoney(t.upgradeCost)}',
                        icon: Icons.upgrade_rounded,
                        color: GH.cyan,
                        enabled: t.level < 5 &&
                            s.money >= t.upgradeCost &&
                            !c.busy,
                        onTap: () => _upgrade(ctx, t),
                      ),
                      const SizedBox(height: 8),
                    ],
                    PrimaryButton(
                      label: mine
                          ? 'ĐỊA BÀN CỦA MÀY'
                          : ally
                              ? 'ĐỒNG MINH — KHÔNG CHÉM'
                              : 'CHIẾM ĐỊA BÀN',
                      icon: mine
                          ? Icons.flag_rounded
                          : (ally
                              ? Icons.handshake_rounded
                              : Icons.sports_mma_rounded),
                      enabled: !mine && !ally,
                      color: mine || ally ? GH.muted : GH.pink,
                      onTap: mine || ally ? null : () => _attack(ctx, t),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _citySection(
    PlayerState s,
    CityInfo city,
    BuildContext sheetContext,
    GameController c,
  ) {
    return NeonPanel(
      color: city.mine ? const Color(0xFF10241C) : const Color(0xFF16161A),
      borderColor: city.mine ? GH.green : GH.line,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_city_rounded,
                size: 15,
                color: city.mine ? GH.green : GH.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'THÀNH ${city.name.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: city.mine ? GH.green : GH.muted,
                  ),
                ),
              ),
              Text('${city.held}/${city.total} ô', style: labelStyle(size: 10.5)),
            ],
          ),
          if (!city.mine)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Giữ trọn ${city.total} ô của quận để mở công trình',
                style: labelStyle(size: 10.5),
              ),
            )
          else ...[
            if (city.goodsRate > 0 || city.incomeMul > 1 || city.defense > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${city.goodsRate.round()} hàng/s'
                  ' · +${((city.incomeMul - 1) * 100).round()}% thu nhập'
                  ' · +${city.defense} thủ',
                  style: labelStyle(size: 10.5, color: GH.cyan),
                ),
              ),
            const SizedBox(height: 8),
            for (final def in s.works) _workRow(s, city, def, sheetContext, c),
          ],
        ],
      ),
    );
  }

  Widget _workRow(
    PlayerState s,
    CityInfo city,
    WorkInfo def,
    BuildContext sheetContext,
    GameController c,
  ) {
    final work = city.work(def.id);
    final level = work?.level ?? 0;
    final cost = work?.cost ?? 0;
    final maxed = level >= def.maxLevel;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${def.name} · cấp $level/${def.maxLevel}',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
                Text(def.desc, style: labelStyle(size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: maxed ? 'MAX' : formatMoney(cost),
            height: 32,
            color: GH.cyan,
            enabled: !maxed && s.money >= cost && !c.busy,
            onTap: maxed ? null : () => _build(sheetContext, city, def),
          ),
        ],
      ),
    );
  }

  String _clock(int until) {
    final left = until - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (left <= 0) return '0:00';
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: labelStyle(size: 12.5)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> _upgrade(BuildContext sheetContext, Territory t) async {
    try {
      await widget.controller.upgradeTerritory(t.id);
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) showToast(context, 'Địa bàn lên cấp ${t.level + 1}');
    } on ApiException catch (e) {
      if (sheetContext.mounted) {
        showToast(sheetContext, e.message, error: true);
      }
    }
  }

  Future<void> _build(
    BuildContext sheetContext,
    CityInfo city,
    WorkInfo def,
  ) async {
    try {
      await widget.controller.buildWork(city.district, def.id);
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) showToast(context, '${def.name} lên cấp');
    } on ApiException catch (e) {
      if (sheetContext.mounted) {
        showToast(sheetContext, e.message, error: true);
      }
    }
  }

  Future<void> _attack(BuildContext sheetContext, Territory t) async {
    Navigator.of(sheetContext).pop();
    try {
      final result = await widget.controller.attack(t.id);
      if (!mounted) return;
      final s = widget.controller.state!;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BrawlScreen(
            result: result,
            playerName: s.name,
            myCount: (s.crew + 1).clamp(1, 5),
            myWeapon: s.weapon.name,
            enemyName: t.ownerName.isEmpty ? 'Băng Ế' : t.ownerName,
          ),
        ),
      );
      if (!mounted) return;
      await widget.controller.reloadTerritoriesQuietly();
      // Chiếm được ô thì nhắc chia quân: ô mới chưa có ai trấn giữ.
      if (!mounted) return;
      if (result.win) {
        showToast(context, 'Ô mới chưa có quân giữ — CHIA TỰ ĐỘNG ở tab Quân');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }
}
