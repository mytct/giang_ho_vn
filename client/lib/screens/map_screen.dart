import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
                      ' · ${s.districtHeld} quận +${(s.districtBonus * 100).round()}%',
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
                  _legend(GH.muted, 'Trống'),
                  const SizedBox(width: 12),
                  _legend(GH.pink, 'Của mày'),
                  const SizedBox(width: 12),
                  _legend(GH.cyan, 'Băng khác'),
                  const SizedBox(width: 12),
                  _legend(GH.green, 'Đồng minh'),
                  const Spacer(),
                  if (s != null)
                    Text('Lực ${s.power}',
                        style: labelStyle(size: 11, color: GH.pink)),
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
                          const CircularProgressIndicator(color: GH.pink),
                          const SizedBox(height: 12),
                          Text('Đang lấy bản đồ...',
                              style: labelStyle(size: 12)),
                        ],
                      ),
                    )
                  : RpgMapView(
                      territories: c.territories,
                      myId: s?.playerId ?? '',
                      myGangId: s?.gangId ?? '',
                      onTap: _openTerritory,
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
                    Text(t.name,
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
          );
        },
      ),
    );
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
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }
}
