import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'level_sheet.dart';

const _crewNames = [
  'Tý Sẹo',
  'Mập Bến Tre',
  'Ốc Xỉn',
  'Cu Lì',
  'Hai Lúa',
  'Chị Đại',
  'Thằng Đệ',
  'Ông Kẹ',
  'Bé Bự',
  'Chú Bảy',
];

class CrewScreen extends StatelessWidget {
  const CrewScreen({super.key, required this.controller});

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
        final next = s.nextWeapon;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BĂNG CỦA MÀY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2),
                    ),
                  ),
                  StatChip(
                      icon: Icons.fitness_center_rounded,
                      value: '${s.power}',
                      label: 'lực',
                      color: GH.pink),
                  const SizedBox(width: 12),
                  StatChip(
                      icon: Icons.groups_rounded,
                      value: '${s.crew}',
                      label: 'quân',
                      color: GH.cyan),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  NeonPanel(
                    borderColor: GH.cyan.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GH.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GH.cyan.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${s.level}',
                            style: const TextStyle(
                                color: GH.cyan,
                                fontSize: 19,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cấp ${s.level}',
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                s.points > 0
                                    ? '${s.xp}/${s.xpNext} EXP · ${s.points} điểm chưa chia'
                                    : '${s.xp}/${s.xpNext} EXP',
                                style: labelStyle(
                                    size: 11,
                                    color: s.points > 0
                                        ? GH.gold
                                        : GH.muted),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: PrimaryButton(
                            label: s.points > 0 ? 'CHIA' : 'XEM',
                            icon: Icons.auto_graph_rounded,
                            color: GH.cyan,
                            height: 38,
                            onTap: () => showLevelSheet(context, controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  NeonPanel(
                    borderColor: GH.cyan.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('ĐỘI HÌNH',
                                style: labelStyle(
                                    size: 10.5, color: GH.text)),
                            const Spacer(),
                            Text('${s.availableCrew} quân đi chém',
                                style: labelStyle(
                                    size: 9.5, color: GH.cyan)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _FormationChip(
                              label: 'Cân bằng',
                              hint: 'chuẩn',
                              value: 'balanced',
                              current: s.formation,
                              onTap: () => _setFormation(context, controller, 'balanced'),
                            ),
                            const SizedBox(width: 6),
                            _FormationChip(
                              label: 'Tiên phong',
                              hint: '+15% dmg, −10% máu',
                              value: 'front',
                              current: s.formation,
                              onTap: () => _setFormation(context, controller, 'front'),
                            ),
                            const SizedBox(width: 6),
                            _FormationChip(
                              label: 'Đánh lén',
                              hint: 'đòn hiểm nhanh, −10% dmg',
                              value: 'sneak',
                              current: s.formation,
                              onTap: () => _setFormation(context, controller, 'sneak'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quân giữ đất không đi chém, nhưng mỗi đứa +10 phòng thủ cho ô đó.',
                          style: labelStyle(size: 9.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  NeonPanel(
                    borderColor: GH.cyan.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('CHIA QUÂN GIỮ ĐẤT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: labelStyle(
                                      size: 10.5, color: GH.text)),
                            ),
                          ],
                        ),
                        Text(
                          '${s.guardsTotal}/${s.crew} đàn em · '
                          '${s.guardedMinions}/${s.minionHealthy} lính',
                          style: labelStyle(size: 9.5),
                        ),
                        const SizedBox(height: 6),
                        if (s.guards.isEmpty)
                          Text(
                            'Chưa có địa bàn nào. Chiếm ô trước rồi chia quân.',
                            style: labelStyle(size: 10),
                          )
                        else
                          for (final slot in s.guards)
                            _GuardRow(
                              slot: slot,
                              canAddCrew: s.guardsTotal < s.crew,
                              canAddMinions:
                                  s.guardedMinions < s.minionHealthy,
                              busy: controller.busy,
                              onChanged: (crew, minions) => _assignGuard(
                                  context,
                                  controller,
                                  slot.territoryId,
                                  crew,
                                  minions),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  NeonPanel(
                    borderColor: GH.gold.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GH.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GH.gold.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.gavel_rounded,
                              color: GH.gold, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.weapon.name,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                next == null
                                    ? 'Hàng nóng xịn nhất rồi'
                                    : 'Lên ${next.name}: ${next.dmg} dmg',
                                style: labelStyle(size: 11),
                              ),
                            ],
                          ),
                        ),
                        if (next != null)
                          SizedBox(
                            width: 108,
                            child: PrimaryButton(
                              label: formatMoney(next.cost),
                              icon: Icons.arrow_upward_rounded,
                              height: 38,
                              enabled:
                                  s.money >= next.cost && !controller.busy,
                              onTap: () => _buyWeapon(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  NeonPanel(
                    borderColor: GH.cyan.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GH.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GH.cyan.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded,
                              color: GH.cyan, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Mộ thêm đàn em',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                'Mỗi đàn em +6 lực, +20 máu khi chém',
                                style: labelStyle(size: 11),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 108,
                          child: PrimaryButton(
                            label: formatMoney(s.crewCost),
                            icon: Icons.add_rounded,
                            color: GH.cyan,
                            height: 38,
                            enabled:
                                s.money >= s.crewCost && !controller.busy,
                            onTap: () => _recruit(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('ĐÀN EM (${s.crew})',
                          style: labelStyle(size: 11, color: GH.text)),
                      const Spacer(),
                      Text('+${s.crew * 6} lực từ quân',
                          style: labelStyle(size: 10.5, color: GH.cyan)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (s.crew == 0)
                    NeonPanel(
                      color: GH.bg2,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: GH.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chưa có đàn em nào. Ra đường một mình là bị hội đồng đó.',
                              style: labelStyle(size: 11.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (var i = 0; i < s.crew; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: NeonPanel(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: GH.panel2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: GH.line),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: GH.cyan),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CrewIdentity(
                                  index: i,
                                  skill: i < s.crewSkills.length
                                      ? s.crewSkills[i]
                                      : null,
                                ),
                              ),
                              Text('+6 lực',
                                  style: labelStyle(
                                      size: 10.5, color: GH.muted)),
                              const SizedBox(width: 10),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: GH.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 10),
                  Text(
                    'Đàn em tự động theo mày vào mọi trận. Thua thì tụi nó chạy trước.',
                    style: labelStyle(size: 10.5)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),
                  _MinionPanel(
                    state: s,
                    busy: controller.busy,
                    onRecruit: () => _recruitMinions(context, 10),
                    onHeal: () => _healMinions(context),
                    onGear: (id, count) => _buyGear(context, id, count),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('TƯỚNG LĨNH (${s.generals.length}/3)',
                          style: labelStyle(size: 11, color: GH.text)),
                      const Spacer(),
                      Text('+${s.generalPower} lực',
                          style: labelStyle(size: 10.5, color: GH.pink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final g in s.generals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: NeonPanel(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            const Icon(Icons.military_tech_rounded,
                                size: 20, color: GH.pink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${g.name} · Lv ${g.level}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                    '${g.skillA.name} · ${g.skillB.name} · +${g.power} lực',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: labelStyle(size: 9.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 92,
                              child: PrimaryButton(
                                label: g.level >= 10
                                    ? 'MAX'
                                    : formatMoney(g.trainCost),
                                icon: Icons.fitness_center_rounded,
                                height: 34,
                                color: GH.pink,
                                enabled: g.level < 10 &&
                                    s.money >= g.trainCost &&
                                    !controller.busy,
                                onTap: () => _trainGeneral(context, g.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (s.generals.length < 3)
                    NeonPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.person_search_rounded,
                              size: 20, color: GH.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mời tướng: +lực, +máu, 2 kỹ năng. Thua trận có thể mất xác.',
                              style: labelStyle(size: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: PrimaryButton(
                              label: formatMoney(s.generalCost),
                              icon: Icons.add_rounded,
                              height: 34,
                              color: GH.pink,
                              enabled: s.money >= s.generalCost &&
                                  !controller.busy,
                              onTap: () => _recruitGeneral(context),
                            ),
                          ),
                        ],
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

  Future<void> _recruit(BuildContext context) async {
    final before = controller.state?.crewSkills.length ?? 0;
    try {
      await controller.recruit();
      final skills = controller.state?.crewSkills ?? const [];
      if (context.mounted && skills.length > before) {
        final skill = skills.last;
        final name = _crewNames[(skills.length - 1) % _crewNames.length];
        showToast(context, 'Tân binh $name · ${skill.name}');
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _recruitGeneral(BuildContext context) async {
    try {
      await controller.recruitGeneral();
      final list = controller.state?.generals ?? const [];
      final g = list.isEmpty ? null : list.last;
      if (context.mounted) {
        showToast(context, g == null ? 'Đã mời tướng' : 'Tướng ${g.name} nhập băng');
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _trainGeneral(BuildContext context, String id) async {
    try {
      await controller.trainGeneral(id);
      if (context.mounted) showToast(context, 'Tướng lên cấp');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _buyWeapon(BuildContext context) async {
    try {
      await controller.upgradeWeapon();
      if (context.mounted) {
        showToast(context, 'Đã lên đồ mới, bớt bị đập rồi');
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _recruitMinions(BuildContext context, int count) async {
    try {
      await controller.recruitMinions(count);
      if (context.mounted) showToast(context, 'Mộ thêm $count lính');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _healMinions(BuildContext context) async {
    final wounds = controller.state?.wounds ?? 0;
    try {
      await controller.healMinions(wounds);
      if (context.mounted) showToast(context, 'Đã băng bó $wounds lính');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _buyGear(BuildContext context, String id, int count) async {
    try {
      await controller.buyMinionGear(id, count);
      if (context.mounted) showToast(context, 'Đã mua $count vũ khí cho lính');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}


class _MinionPanel extends StatelessWidget {
  const _MinionPanel({
    required this.state,
    required this.busy,
    required this.onRecruit,
    required this.onHeal,
    required this.onGear,
  });

  final PlayerState state;
  final bool busy;
  final VoidCallback onRecruit;
  final VoidCallback onHeal;
  final void Function(String id, int count) onGear;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final room = s.maxMinions - s.minions;
    final recruitCount = room >= 10 ? 10 : room;
    final recruitCost = s.minionRecruitCost * recruitCount;
    final healCost = s.wounds * s.minionHealCost;
    final totalGear = s.minionGear.fold<int>(0, (a, g) => a + g.owned);
    final gearRoom = s.minions - totalGear;
    return NeonPanel(
      borderColor: GH.gold.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_rounded, color: GH.gold, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('LÍNH ĐÔNG',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w900)),
              ),
              Text('${s.minions}/${s.maxMinions}',
                  style: labelStyle(size: 10, color: GH.gold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${s.minionHealthy} khỏe · ${s.wounds} bị thương · +${s.minionPower} lực',
            style: labelStyle(size: 10),
          ),
          Text(
            'ăn ${s.goodsUpkeep.toStringAsFixed(1)} hàng/s · đang có ${s.goods.round()}',
            style: labelStyle(
              size: 10,
              color: s.goodsUpkeep > s.goodsRate ? GH.red : GH.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: recruitCount > 0 ? 'MỘ +$recruitCount' : 'ĐẦY LÍNH',
                  height: 34,
                  color: GH.cyan,
                  enabled: recruitCount > 0 &&
                      !busy &&
                      s.money >= recruitCost,
                  onTap: onRecruit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: s.wounds > 0 ? 'BĂNG BÓ' : 'SẠCH SẼ',
                  height: 34,
                  color: GH.green,
                  enabled: s.wounds > 0 && !busy && s.money >= healCost,
                  onTap: onHeal,
                ),
              ),
            ],
          ),
          if (recruitCount > 0 || s.wounds > 0) ...[
            const SizedBox(height: 5),
            Text(
              '${recruitCount > 0 ? 'Mộ ${formatMoney(recruitCost)} đ' : ''}'
              '${recruitCount > 0 && s.wounds > 0 ? ' · ' : ''}'
              '${s.wounds > 0 ? 'Băng bó ${formatMoney(healCost)} đ' : ''}',
              style: labelStyle(size: 9),
            ),
          ],
          const SizedBox(height: 8),
          for (final g in s.minionGear) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                      Text('đang có ${g.owned} · ${g.desc}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle(size: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: PrimaryButton(
                    label: formatMoney(g.cost),
                    height: 30,
                    color: GH.gold,
                    enabled: gearRoom > 0 && !busy && s.money >= g.cost,
                    onTap: () => onGear(g.id, 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(
            'Đánh nhau là lính bị thương, thương binh không ra trận (tự hồi 1/phút). Mua dao/kiếm cho lính để tăng lực, băng bó để hồi quân.',
            style: labelStyle(size: 9),
          ),
        ],
      ),
    );
  }
}

Color _skillColor(String rarity) {
  switch (rarity) {
    case 'Đặc biệt':
      return GH.gold;
    case 'Hiếm':
      return GH.cyan;
    default:
      return GH.muted;
  }
}

class _CrewIdentity extends StatelessWidget {
  const _CrewIdentity({required this.index, required this.skill});

  final int index;
  final CrewSkill? skill;

  @override
  Widget build(BuildContext context) {
    final s = skill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                _crewNames[index % _crewNames.length],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            if (s != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _skillColor(s.rarity).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.rarity == 'Đặc biệt' ? 'ĐẶC BIỆT' : s.rarity.toUpperCase(),
                  style: labelStyle(size: 7.5, color: _skillColor(s.rarity)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          s == null ? 'chưa có kỹ năng' : '${s.name} · ${s.desc}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle(
            size: 9.5,
            color: s == null ? GH.muted : _skillColor(s.rarity),
          ),
        ),
      ],
    );
  }
}


Future<void> _setFormation(
  BuildContext context,
  GameController c,
  String kind,
) async {
  try {
    await c.setFormation(kind);
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

Future<void> _assignGuard(
  BuildContext context,
  GameController c,
  int territoryId,
  int crew,
  int minions,
) async {
  try {
    await c.assignGuard(territoryId, crew, minions);
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

class _FormationChip extends StatelessWidget {
  const _FormationChip({
    required this.label,
    required this.hint,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String value;
  final String current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? GH.cyan.withValues(alpha: 0.14)
                : GH.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? GH.cyan.withValues(alpha: 0.6) : GH.line,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? GH.cyan : GH.text,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
              Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle(size: 7.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardRow extends StatelessWidget {
  const _GuardRow({
    required this.slot,
    required this.canAddCrew,
    required this.canAddMinions,
    required this.busy,
    required this.onChanged,
  });

  final GuardSlot slot;
  final bool canAddCrew;
  final bool canAddMinions;
  final bool busy;
  final void Function(int crew, int minions) onChanged;

  @override
  Widget build(BuildContext context) {
    final defense = slot.count * 10 + slot.minions ~/ 2;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(slot.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              Text('+$defense thủ',
                  style: labelStyle(size: 9.5, color: GH.cyan)),
            ],
          ),
          const SizedBox(height: 3),
          _line('đàn em', slot.count, 1, canAddCrew,
              (v) => onChanged(v, slot.minions)),
          _line('lính', slot.minions, 10, canAddMinions,
              (v) => onChanged(slot.count, v)),
        ],
      ),
    );
  }

  Widget _line(
    String label,
    int value,
    int step,
    bool canAdd,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 46, child: Text(label, style: labelStyle(size: 9.5))),
        _stepBtn('−', value > 0 && !busy,
            () => onChanged((value - step).clamp(0, value))),
        SizedBox(
          width: 34,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        _stepBtn('+', canAdd && !busy, () => onChanged(value + step)),
      ],
    );
  }

  Widget _stepBtn(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GH.panel2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GH.line),
        ),
        child: Text(label,
            style: TextStyle(
                color: enabled ? GH.cyan : GH.muted,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}
