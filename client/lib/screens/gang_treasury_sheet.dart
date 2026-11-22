import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showGangTreasurySheet(
  BuildContext context,
  GameController c,
  GangInfo gang,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        GangInfo g = gang;
        for (final item in c.gangs) {
          if (item.id == gang.id) g = item;
        }
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final boostLeft = g.boostUntil - now;
        final shieldLeft = g.shieldCooldownUntil - now;
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.savings_rounded,
                          color: GH.gold, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('QUỸ BĂNG',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      Text('${formatMoney(g.treasury)} đ',
                          style: moneyStyle(size: 18)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cấp băng ${g.level} · ${g.allies} đồng minh · ${g.wars} cuộc chiến'
                    '${boostLeft > 0 ? ' · chiến phí còn ${(boostLeft / 60).ceil()} phút' : ''}',
                    style: labelStyle(
                        size: 10,
                        color: boostLeft > 0 ? GH.red : GH.muted),
                  ),
                  if (!g.isLeader)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded,
                              size: 12, color: GH.gold),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Chỉ băng trưởng (${g.leader}) mới tiêu quỹ',
                              style: labelStyle(size: 10, color: GH.gold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  _option(
                    icon: Icons.trending_up_rounded,
                    color: GH.cyan,
                    title: 'Nâng lực băng',
                    desc: '+1% lực toàn băng vĩnh viễn',
                    cost: g.upgradeCost,
                    short: g.treasury >= g.upgradeCost
                        ? null
                        : g.upgradeCost - g.treasury,
                    enabled: g.isLeader && !c.busy,
                    onTap: () => _buy(ctx, c, 'power', 'Đã nâng lực băng'),
                  ),
                  const SizedBox(height: 8),
                  _option(
                    icon: Icons.shield_rounded,
                    color: GH.green,
                    title: 'Khiên băng 30 phút',
                    desc: shieldLeft > 0
                        ? 'Đang hồi, còn ${(shieldLeft / 60).ceil()} phút'
                        : 'Cả băng không bị đánh trong 30 phút',
                    cost: 2500,
                    short:
                        g.treasury >= 2500 ? null : 2500 - g.treasury,
                    enabled: g.isLeader && !c.busy && shieldLeft <= 0,
                    onTap: () => _buy(ctx, c, 'shield', 'Khiên băng đã bật'),
                  ),
                  const SizedBox(height: 8),
                  _option(
                    icon: Icons.local_fire_department_rounded,
                    color: GH.red,
                    title: 'Chiến phí 30 phút',
                    desc: '+10% lực khi đi chém',
                    cost: 2000,
                    short: g.treasury >= 2000 ? null : 2000 - g.treasury,
                    enabled: g.isLeader && !c.busy,
                    onTap: () => _buy(ctx, c, 'boost', 'Chiến phí đã bật'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Quỹ đến từ băng yếu nộp cống (10% thu nhập) và thưởng chiến băng lúc 22:00.',
                    style: labelStyle(size: 10),
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

Widget _option({
  required IconData icon,
  required Color color,
  required String title,
  required String desc,
  required int cost,
  required int? short,
  required bool enabled,
  required VoidCallback onTap,
}) {
  final canTap = enabled && short == null;
  return Opacity(
    opacity: short == null ? 1 : 0.45,
    child: NeonPanel(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text(desc, style: labelStyle(size: 9.5)),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: PrimaryButton(
              label: short == null
                  ? formatMoney(cost)
                  : 'THIẾU ${formatMoney(short)}',
              height: 34,
              color: color,
              enabled: canTap,
              onTap: onTap,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _buy(
  BuildContext ctx,
  GameController c,
  String kind,
  String message,
) async {
  try {
    await c.upgradeGang(kind);
    if (ctx.mounted) showToast(ctx, message);
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}
