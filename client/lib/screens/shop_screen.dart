import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.state;
        if (s == null) {
          return const Center(
              child: CircularProgressIndicator(color: GH.pink));
        }
        final currentIdx =
            s.weapons.indexWhere((w) => w.name == s.weapon.name);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'CHỢ ĐEN',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  Icon(Icons.payments_rounded, size: 15, color: GH.gold),
                  const SizedBox(width: 5),
                  Text(formatMoney(s.money), style: moneyStyle(size: 16)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  Text('HÀNG NÓNG',
                      style: labelStyle(size: 11, color: GH.text)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < s.weapons.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WeaponRow(
                        weapon: s.weapons[i],
                        index: i,
                        current: currentIdx < 0 ? 0 : currentIdx,
                        money: s.money,
                        busy: controller.busy,
                        onBuy: () => _buy(context),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text('ĐỒ CHƠI DÂN CHƠI',
                      style: labelStyle(size: 11, color: GH.text)),
                  const SizedBox(height: 8),
                  for (final item in const [
                    ('wave', 'Xe Wave độ', '+8% thu nhập từ cơ sở', 5000),
                    ('chain', 'Dây chuyền vàng', '+5% uy khi thắng trận', 8000),
                    ('watch', 'Đồng hồ đểu', '+10% tiền cướp được', 15000),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NeonPanel(
                        color: s.items.contains(item.$1)
                            ? const Color(0xFF101A19)
                            : GH.bg2,
                        borderColor: s.items.contains(item.$1)
                            ? GH.cyan.withValues(alpha: 0.4)
                            : GH.line,
                        child: Row(
                          children: [
                            Icon(
                              s.items.contains(item.$1)
                                  ? Icons.check_circle_rounded
                                  : Icons.lock_rounded,
                              size: 16,
                              color: s.items.contains(item.$1)
                                  ? GH.cyan
                                  : GH.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.$2,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: s.items.contains(item.$1)
                                              ? GH.text
                                              : GH.muted)),
                                  Text(item.$3,
                                      style: labelStyle(size: 10.5)),
                                ],
                              ),
                            ),
                            if (s.items.contains(item.$1))
                              Text('ĐÃ CÓ',
                                  style:
                                      labelStyle(size: 9.5, color: GH.cyan))
                            else
                              SizedBox(
                                width: 88,
                                child: PrimaryButton(
                                  label: formatMoney(item.$4),
                                  height: 32,
                                  enabled: s.money >= item.$4 &&
                                      !controller.busy,
                                  onTap: () => _buyItem(context, item.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buyItem(BuildContext context, String id) async {
    try {
      await controller.buyItem(id);
      if (context.mounted) showToast(context, 'Mua xong, oai hơn hẳn');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _buy(BuildContext context) async {
    try {
      await controller.upgradeWeapon();
      if (context.mounted) showToast(context, 'Xong, hàng về tay');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}

class _WeaponRow extends StatelessWidget {
  const _WeaponRow({
    required this.weapon,
    required this.index,
    required this.current,
    required this.money,
    required this.busy,
    required this.onBuy,
  });

  final WeaponInfo weapon;
  final int index;
  final int current;
  final int money;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final isCurrent = index == current;
    final owned = index < current;
    final isNext = index == current + 1;
    final color = isCurrent ? GH.pink : owned ? GH.muted : GH.gold;

    return NeonPanel(
      borderColor: isCurrent
          ? GH.pink.withValues(alpha: 0.7)
          : GH.line,
      color: isCurrent ? const Color(0xFF1E1219) : GH.panel,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(
              index >= 2 ? Icons.gps_fixed_rounded : Icons.content_cut_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weapon.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: owned ? GH.muted : GH.text)),
                const SizedBox(height: 2),
                Text(
                  '${weapon.dmg} sát thương mỗi đòn',
                  style: labelStyle(size: 10.5),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: GH.pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('ĐANG DÙNG',
                  style: labelStyle(size: 9, color: GH.pink)),
            )
          else if (owned)
            Text('ĐÃ CÓ', style: labelStyle(size: 9.5))
          else
            SizedBox(
              width: 100,
              child: PrimaryButton(
                label: formatMoney(weapon.cost),
                enabled: isNext && money >= weapon.cost && !busy,
                height: 36,
                onTap: onBuy,
              ),
            ),
        ],
      ),
    );
  }
}
