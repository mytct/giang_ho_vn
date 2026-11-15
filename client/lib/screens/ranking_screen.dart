import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../api.dart';
import 'diplomacy_sheet.dart';
import 'gang_treasury_sheet.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.state;
        final rows = controller.ranking;
        if (s == null) {
          return const Center(
              child: CircularProgressIndicator(color: GH.pink));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BĂNG ĐẢNG',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2),
                      ),
                      Text('MÙA ${s.seasonKey}',
                          style: labelStyle(size: 9.5, color: GH.cyan)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      controller.loadRanking().catchError((Object _) {});
                      controller.loadGangs().catchError((Object _) {});
                    },
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: GH.muted),
                  ),
                  IconButton(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded,
                        size: 20, color: GH.muted),
                  ),
                ],
              ),
            ),
            _GangSection(controller: controller, state: s),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('BẢNG BĂNG ĐẢNG',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle(size: 11, color: GH.text)),
                  ),
                  Text('T1 · T2 · T3', style: labelStyle(size: 9.5)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => showDiplomacySheet(context, controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GH.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: GH.cyan.withValues(alpha: 0.35)),
                      ),
                      child: Text('SƠ ĐỒ',
                          style: labelStyle(size: 9, color: GH.cyan)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 210,
              child: controller.gangs.isEmpty
                  ? Center(
                      child: Text('Chưa có băng nào',
                          style: labelStyle(size: 11)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: controller.gangs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _GangRow(
                        gang: controller.gangs[i],
                        onTap: () => _showGangDetail(
                            context, controller, controller.gangs[i]),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('BẢNG UY TÍN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle(size: 11, color: GH.text)),
                  ),
                  Flexible(
                    child: Text('${rows.length} tay chơi · bấm để treo thưởng',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: labelStyle(size: 9)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: GH.pink))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RankRow(
                          row: rows[i],
                          position: i + 1,
                          onTap: () => _showBountySheet(
                              context, controller, rows[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GH.panel,
        title: const Text('Rời hội?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Tiền và địa bàn vẫn giữ trên server. Vào lại bằng tên khác thì phải làm lại từ đầu.',
          style: labelStyle(size: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ở LẠI', style: labelStyle(size: 12, color: GH.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('RỜI', style: labelStyle(size: 12, color: GH.red)),
          ),
        ],
      ),
    );
    if (ok == true) await controller.logout();
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.row,
    required this.position,
    required this.onTap,
  });

  final RankingRow row;
  final int position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medalColor = position == 1
        ? GH.gold
        : position == 2
            ? const Color(0xFFC5CBD8)
            : position == 3
                ? const Color(0xFFD08A52)
                : GH.muted;

    return GestureDetector(
      onTap: onTap,
      child: NeonPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: row.isMe ? const Color(0xFF1D1118) : GH.panel,
      borderColor: row.isMe ? GH.pink.withValues(alpha: 0.75) : GH.line,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$position',
              style: TextStyle(
                color: medalColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (row.isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: GH.pink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('MÀY',
                            style: labelStyle(size: 8, color: GH.pink)),
                      ),
                    ],
                  ],
                ),
                Text(row.rank, style: labelStyle(size: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${formatMoney(row.uy)} uy',
                  style: moneyStyle(size: 12.5, color: GH.gold)),
              const SizedBox(height: 2),
              Text('lực ${row.power} · ${row.owned} ô',
                  style: labelStyle(size: 9.5)),
              if (row.bounty > 0)
                Text('TRUY NÃ ${formatMoney(row.bounty)}',
                    style: labelStyle(size: 9, color: GH.gold)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

Future<void> _showBountySheet(
  BuildContext context,
  GameController controller,
  RankingRow row,
) async {
  final state = controller.state;
  if (state == null) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
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
              Text('TRUY NÃ: ${row.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                '${row.rank} · lực ${row.power} · đang có ${formatMoney(row.bounty)} tiền truy nã',
                style: labelStyle(size: 11),
              ),
              const SizedBox(height: 4),
              Text('Ai hạ được nó trong trận sẽ nhận hết số tiền này.',
                  style: labelStyle(size: 10, color: GH.muted)),
              const SizedBox(height: 16),
              if (row.isMe)
                Text('Không tự treo thưởng lên đầu mình được.',
                    style: labelStyle(size: 11, color: GH.red))
              else
                Row(
                  children: [
                    for (final amount in const [500, 2000, 5000]) ...[
                      Expanded(
                        child: PrimaryButton(
                          label: formatMoney(amount),
                          height: 40,
                          color: GH.gold,
                          enabled: state.money >= amount && !controller.busy,
                          onTap: () async {
                            try {
                              await controller.setBounty(row.id, amount);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                showToast(ctx,
                                    'Đã treo ${formatMoney(amount)} lên đầu ${row.name}');
                              }
                            } on ApiException catch (e) {
                              if (ctx.mounted) {
                                showToast(ctx, e.message, error: true);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              const SizedBox(height: 10),
              Text('Mày đang có ${formatMoney(state.money)} đ',
                  style: labelStyle(size: 10)),
            ],
          ),
        ),
      ),
    ),
  );
}


class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    final color = tier == 1
        ? GH.gold
        : (tier == 2 ? GH.cyan : GH.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text('T$tier',
          style: labelStyle(size: 8, color: color)),
    );
  }
}

class _GangRow extends StatelessWidget {
  const _GangRow({required this.gang, required this.onTap});

  final GangInfo gang;
  final VoidCallback onTap;

  String get _relationLabel {
    switch (gang.relation) {
      case 'self':
        return 'BĂNG MÀY';
      case 'ally':
        return 'ĐỒNG MINH';
      case 'war':
        return 'ĐANG CHIẾN';
      case 'protector':
        return 'NỘP CỐNG';
      case 'tributary':
        return 'THU CỐNG';
      default:
        return '';
    }
  }

  Color get _relationColor {
    switch (gang.relation) {
      case 'self':
        return GH.pink;
      case 'ally':
        return GH.green;
      case 'war':
        return GH.red;
      case 'protector':
        return GH.red;
      case 'tributary':
        return GH.gold;
      default:
        return GH.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: gang.isMine ? const Color(0xFF1D1118) : GH.panel,
        borderColor: gang.isMine
            ? GH.pink.withValues(alpha: 0.55)
            : GH.line,
        child: Row(
          children: [
            _TierChip(tier: gang.tier),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gang.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(
                    '${gang.members}/${gang.maxMembers} · ${formatMoney(gang.power)} lực · ${gang.owned} ô',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle(size: 9),
                  ),
                ],
              ),
            ),
            if (_relationLabel.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _relationColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_relationLabel,
                    style:
                        labelStyle(size: 8, color: _relationColor)),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: GH.muted),
          ],
        ),
      ),
    );
  }
}

Future<void> _breakTribute(
    BuildContext context,
    GameController controller,
  ) async {
  try {
    await controller.breakTribute();
    if (context.mounted) showToast(context, 'Đã cắt cống nộp');
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

class _GangSection extends StatelessWidget {
  const _GangSection({required this.controller, required this.state});

  final GameController controller;
  final PlayerState state;

  GangInfo? get _mine {
    for (final g in controller.gangs) {
      if (g.isMine) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s.gangId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: NeonPanel(
          color: const Color(0xFF141019),
          borderColor: GH.gold.withValues(alpha: 0.3),
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
                    ),
                    child: const Icon(Icons.groups_3_rounded,
                        color: GH.gold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chưa có băng',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(
                          'Lập băng 2.000đ · mỗi thành viên +2% lực khi chém',
                          style: labelStyle(size: 10.5),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 118,
                    child: PrimaryButton(
                      label: 'LẬP BĂNG',
                      height: 36,
                      onTap: () => _createGangDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'TÌM BĂNG ĐỂ VÀO',
                  icon: Icons.search_rounded,
                  color: GH.cyan,
                  height: 36,
                  onTap: () => _gangPicker(context, war: false),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mine = _mine;
    final warName = mine?.warName ?? '';
    final bonus = ((s.gangBonus - 1) * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: NeonPanel(
        color: const Color(0xFF101A19),
        borderColor: GH.cyan.withValues(alpha: 0.35),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GH.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: GH.cyan.withValues(alpha: 0.35)),
                  ),
                  child:
                      const Icon(Icons.shield_rounded, color: GH.cyan, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (mine != null) ...[
                            _TierChip(tier: mine.tier),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(s.gangName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      Text(
                        '${s.gangMembers}/10 thành viên'
                        '${mine == null ? '' : ' · ${mine.power} lực · ${mine.owned} ô'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle(size: 10.5),
                      ),
                      if (mine != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lv ${mine.level} · ${mine.allies} đồng minh · ${mine.wars} chiến · ${formatMoney(mine.treasury)} quỹ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle(
                                    size: 9.5, color: GH.muted),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => showGangTreasurySheet(
                                  context, controller, mine),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: GH.gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('QUỸ',
                                    style: labelStyle(
                                        size: 8, color: GH.gold)),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        (mine?.warOpen ?? false)
                            ? 'Chiến băng ĐANG MỞ · ${mine?.warScore ?? 0} điểm · thưởng 22:00'
                            : 'Chiến băng 20:00–22:00 · ${mine?.warScore ?? 0} điểm · thưởng 22:00',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle(
                            size: 9,
                            color: (mine?.warOpen ?? false)
                                ? GH.red
                                : GH.muted),
                      ),
                      if ((mine?.tributeToName ?? '').isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đang nộp 10% cho ${mine!.tributeToName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle(size: 9, color: GH.red),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _breakTribute(context, controller),
                              child: Text('CẮT',
                                  style: labelStyle(
                                      size: 9, color: GH.gold)),
                            ),
                          ],
                        )
                      else if ((mine?.tributes ?? 0) > 0)
                        Text(
                          'Đang thu cống ${mine!.tributes} băng',
                          style: labelStyle(size: 9, color: GH.green),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GH.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+$bonus% lực',
                      style: labelStyle(size: 9.5, color: GH.cyan)),
                ),
              ],
            ),
            if (warName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: GH.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GH.red.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 14, color: GH.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đang chiến với $warName · còn ${_warMinutes(mine!.warUntil)} phút',
                        style: labelStyle(size: 10, color: GH.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (warName.isEmpty &&
                _warMinutes(mine?.warCooldownUntil ?? 0) > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Vừa dứt chiến · nghỉ ${_warMinutes(mine!.warCooldownUntil)} phút mới tuyên chiến tiếp',
                style: labelStyle(size: 9, color: GH.gold),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'TUYÊN CHIẾN',
                    color: GH.red,
                    height: 34,
                    enabled: warName.isEmpty &&
                        _warMinutes(mine?.warCooldownUntil ?? 0) == 0,
                    onTap: () => _gangPicker(context, war: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: 'RỜI BĂNG',
                    color: GH.muted,
                    height: 34,
                    onTap: () => _confirmLeave(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _warMinutes(int untilUnix) {
    final left = untilUnix - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return left <= 0 ? 0 : (left / 60).ceil();
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GH.panel,
        title: const Text('Rời băng?'),
        content: Text('Mày sẽ mất buff lực và không còn được đồng minh bảo kê.',
            style: labelStyle(size: 12.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Ở LẠI', style: labelStyle(size: 12))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('RỜI', style: labelStyle(size: 12, color: GH.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.leaveGang();
      if (context.mounted) showToast(context, 'Đã rời băng');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _createGangDialog(BuildContext context) async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GH.panel,
        title: const Text('Lập băng'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            hintText: 'Tên băng, ví dụ: Băng Rắn Độc',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('HỦY', style: labelStyle(size: 12))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, input.text.trim()),
              child: Text('LẬP', style: labelStyle(size: 12, color: GH.pink))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await controller.createGang(name);
      if (context.mounted) showToast(context, 'Băng $name đã dựng cờ');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _gangPicker(BuildContext context, {required bool war}) async {
    try {
      await controller.loadGangs();
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: controller,
        builder: (ctx, _) {
          final others =
              controller.gangs.where((g) => !g.isMine).toList();
          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.65,
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
                    child: Row(
                      children: [
                        Text(war ? 'TUYÊN CHIẾN' : 'CHỌN BĂNG',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: GH.muted, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: others.isEmpty
                        ? Center(
                            child: Text('Chưa có băng nào khác',
                                style: labelStyle(size: 12)))
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: others.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final g = others[i];
                              return NeonPanel(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(g.name,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w800)),
                                          Text(
                                            '${g.members}/10 · ${g.power} lực · ${g.owned} ô · trưởng ${g.leader}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: labelStyle(size: 9.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 84,
                                      child: PrimaryButton(
                                        label: war ? 'CHIẾN' : 'VÀO',
                                        height: 32,
                                        color: war ? GH.red : GH.cyan,
                                        enabled: !controller.busy,
                                        onTap: () => _act(ctx, g, war),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  Future<void> _act(BuildContext ctx, GangInfo g, bool war) async {
    try {
      if (war) {
        await controller.declareWar(g.id);
        if (ctx.mounted) {
          showToast(ctx, 'Đã tuyên chiến với ${g.name}');
          Navigator.of(ctx).pop();
        }
      } else {
        await controller.joinGang(g.id);
        if (ctx.mounted) {
          showToast(ctx, 'Đã vào ${g.name}');
          Navigator.of(ctx).pop();
        }
      }
    } on ApiException catch (e) {
      if (ctx.mounted) showToast(ctx, e.message, error: true);
    }
  }
}


Future<void> _showGangDetail(
  BuildContext context,
  GameController c,
  GangInfo g,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
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
                  _TierChip(tier: g.tier),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                  if (g.warOpen)
                    Text('CHIẾN BĂNG MỞ',
                        style: labelStyle(size: 9, color: GH.red)),
                ],
              ),
              const SizedBox(height: 12),
              _gangRow('Băng trưởng', g.leader),
              _gangRow('Thành viên', '${g.members}/${g.maxMembers}'),
              _gangRow('Tổng lực', formatMoney(g.power)),
              _gangRow('Địa bàn', '${g.owned} ô'),
              _gangRow('Quỹ băng', '${formatMoney(g.treasury)} đ', GH.gold),
              _gangRow('Đồng minh / chiến', '${g.allies} / ${g.wars}'),
              if (g.tributeToName.isNotEmpty)
                _gangRow('Đang nộp cống', g.tributeToName, GH.red),
              if (g.tributes > 0)
                _gangRow('Đang thu cống', '${g.tributes} băng', GH.green),
              const SizedBox(height: 16),
              ..._actions(ctx, c, g),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _gangRow(String label, String value, [Color color = GH.text]) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: labelStyle(size: 12)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

List<Widget> _actions(BuildContext ctx, GameController c, GangInfo g) {
  switch (g.relation) {
    case 'self':
      return [
        Text('Băng của mày. Vào tab này để quản lý quan hệ.',
            style: labelStyle(size: 10.5)),
      ];
    case 'war':
      return [
        NeonPanel(
          color: const Color(0xFF2A1218),
          borderColor: GH.red,
          child: Text(
            'ĐANG CHIẾN. Chém vào địa bàn của băng này để ăn điểm chiến.',
            style: labelStyle(size: 10.5, color: GH.red),
          ),
        ),
      ];
    case 'ally':
      return [
        PrimaryButton(
          label: 'CẮT LIÊN MINH',
          color: GH.muted,
          height: 40,
          onTap: () => _doGangAction(ctx, c, g, 'unally'),
        ),
      ];
    case 'protector':
      return [
        Text('Băng mày đang nộp 10% thu nhập cho băng này.',
            style: labelStyle(size: 10.5, color: GH.red)),
      ];
    case 'tributary':
      return [
        Text('Băng này đang nộp cống 10% thu nhập cho mày.',
            style: labelStyle(size: 10.5, color: GH.green)),
      ];
    default:
      return [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'KẾT MINH',
                color: GH.green,
                height: 40,
                enabled: !c.busy,
                onTap: () => _doGangAction(ctx, c, g, 'ally'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                label: 'ĐÒI CỐNG',
                color: GH.gold,
                height: 40,
                enabled: !c.busy,
                onTap: () => _doGangAction(ctx, c, g, 'tribute'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'TUYÊN CHIẾN',
          color: GH.red,
          height: 40,
          enabled: !c.busy,
          onTap: () => _doGangAction(ctx, c, g, 'war'),
        ),
      ];
  }
}

Future<void> _doGangAction(
  BuildContext ctx,
  GameController c,
  GangInfo g,
  String action,
) async {
  try {
    String message;
    switch (action) {
      case 'ally':
        await c.allyGang(g.id);
        message = 'Đã kết minh với ${g.name}';
      case 'unally':
        await c.unallyGang(g.id);
        message = 'Đã cắt liên minh với ${g.name}';
      case 'tribute':
        await c.demandTribute(g.id);
        message = 'Đã bắt ${g.name} nộp cống';
      default:
        await c.declareWar(g.id);
        message = 'Đã tuyên chiến với ${g.name} và đồng minh của nó';
    }
    if (ctx.mounted) {
      Navigator.of(ctx).pop();
      showToast(ctx, message);
    }
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}
