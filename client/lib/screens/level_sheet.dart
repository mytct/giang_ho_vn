import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showLevelSheet(BuildContext context, GameController controller) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final s = controller.state;
        if (s == null) return const SizedBox.shrink();
        final canSpend = s.points > 0 && !controller.busy;
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
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GH.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: GH.cyan.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          '${s.level}',
                          style: const TextStyle(
                              color: GH.cyan,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cấp ${s.level}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('${s.xp}/${s.xpNext} EXP',
                                style: labelStyle(size: 11)),
                          ],
                        ),
                      ),
                      if (s.points > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: GH.gold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: GH.gold.withValues(alpha: 0.45)),
                          ),
                          child: Text('${s.points} ĐIỂM',
                              style:
                                  labelStyle(size: 10.5, color: GH.gold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.expRatio,
                      minHeight: 6,
                      backgroundColor: GH.line,
                      valueColor: const AlwaysStoppedAnimation(GH.cyan),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatRow(
                    icon: Icons.favorite_rounded,
                    color: GH.red,
                    title: 'Máu',
                    effect: '+25 máu mỗi điểm',
                    current: '+${s.bonusHp} máu (${s.statHp} điểm)',
                    enabled: canSpend,
                    onTap: () => _spend(ctx, controller, 'hp'),
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    icon: Icons.gavel_rounded,
                    color: GH.pink,
                    title: 'Sát thương',
                    effect: '+3 dmg mỗi điểm',
                    current: '+${s.bonusDmg} dmg (${s.statDmg} điểm)',
                    enabled: canSpend,
                    onTap: () => _spend(ctx, controller, 'dmg'),
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    icon: Icons.shield_rounded,
                    color: GH.cyan,
                    title: 'Lì đòn',
                    effect: '−2% sát thương nhận mỗi điểm (tối đa 50%)',
                    current:
                        '−${(s.damageReduction * 100).round()}% (${s.statArmor}/25 điểm)',
                    enabled: canSpend && s.statArmor < 25,
                    onTap: () => _spend(ctx, controller, 'armor'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.points > 0
                        ? 'Chia điểm vào chỗ mày hay chết nhất.'
                        : 'Thắng trận, nâng cơ sở, mộ quân, nhận nhiệm vụ để kiếm EXP.',
                    style: labelStyle(size: 10.5),
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

Future<void> _spend(BuildContext ctx, GameController c, String stat) async {
  try {
    await c.spendPoint(stat);
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.effect,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String effect;
  final String current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                        fontSize: 13, fontWeight: FontWeight.w800)),
                Text(effect, style: labelStyle(size: 9.5)),
                const SizedBox(height: 2),
                Text(current,
                    style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: PrimaryButton(
              label: '+',
              height: 34,
              color: color,
              enabled: enabled,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
