import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'brawl_screen.dart';

String _clock(int unix) {
  final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _timer(int seconds) {
  if (seconds <= 0) return 'hết hạn';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Widget _sheetShell({
  required Widget child,
  double heightFactor = 0.75,
}) {
  return FractionallySizedBox(
    heightFactor: heightFactor,
    child: Container(
      decoration: const BoxDecoration(
        color: GH.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GH.line)),
      ),
      child: SafeArea(top: false, child: child),
    ),
  );
}

Widget _sheetHeader(BuildContext ctx, String title, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
    child: Column(
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
        const SizedBox(height: 12),
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
            const Spacer(),
            ?trailing,
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: GH.muted, size: 20),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> showInboxSheet(BuildContext context, GameController c) async {
  try {
    await c.loadInbox();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final unread = c.inbox.where((m) => !m.read).length;
        return _sheetShell(
          child: Column(
            children: [
              _sheetHeader(
                ctx,
                'HỘP THƯ',
                trailing: TextButton(
                  onPressed: unread == 0
                      ? null
                      : () async {
                          try {
                            await c.readInbox();
                          } on ApiException catch (e) {
                            if (ctx.mounted) {
                              showToast(ctx, e.message, error: true);
                            }
                          }
                        },
                  child: Text(
                    unread == 0 ? 'ĐÃ ĐỌC HẾT' : 'ĐỌC HẾT ($unread)',
                    style: labelStyle(
                        size: 10.5,
                        color: unread == 0 ? GH.muted : GH.cyan),
                  ),
                ),
              ),
              Expanded(
                child: c.inbox.isEmpty
                    ? Center(
                        child: Text('Chưa có tin gì',
                            style: labelStyle(size: 12)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: c.inbox.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = c.inbox[i];
                          final color = m.kind == 'attack'
                              ? GH.red
                              : (m.kind == 'boss' ? GH.gold : GH.cyan);
                          return NeonPanel(
                            color: m.read ? GH.bg2 : const Color(0xFF171B24),
                            borderColor: m.read
                                ? GH.line
                                : color.withValues(alpha: 0.5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  m.kind == 'attack'
                                      ? Icons.gavel_rounded
                                      : (m.kind == 'boss'
                                          ? Icons.whatshot_rounded
                                          : Icons.assignment_turned_in_rounded),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.text,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: m.read
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              height: 1.25)),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_clock(m.at)}'
                                        '${m.revengeActive ? ' · còn ${_timer(m.revengeUntil - DateTime.now().millisecondsSinceEpoch ~/ 1000)} để báo thù (+25% loot)' : ''}',
                                        style: labelStyle(
                                            size: 9.5,
                                            color: m.revengeActive
                                                ? GH.gold
                                                : GH.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!m.read)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                                if (m.kind == 'attack')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        if (m.battleId.isNotEmpty)
                                          TextButton(
                                            onPressed: () => _replayDefense(
                                                ctx, c, m),
                                            child: Text('XEM LẠI',
                                                style: labelStyle(
                                                    size: 9.5,
                                                    color: GH.cyan)),
                                          ),
                                        if (m.revengeActive)
                                          TextButton(
                                            onPressed: () =>
                                                _revenge(ctx, c, m),
                                            child: Text('PHẢN CÔNG',
                                                style: labelStyle(
                                                    size: 9.5,
                                                    color: GH.red)),
                                          ),
                                      ],
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
        );
      },
    ),
  );
}

Future<void> showContractsSheet(BuildContext context, GameController c) async {
  try {
    await c.loadContracts();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final s = c.state;
        if (s == null) return const SizedBox.shrink();
        final active = s.contract;
        return _sheetShell(
          child: Column(
            children: [
              _sheetHeader(ctx, 'HỢP ĐỒNG'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    if (active != null) ...[
                      _ActiveContract(
                        contract: active,
                        busy: c.busy,
                        onClaim: () => _claimContract(ctx, c),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Text(
                        'Chọn 1 hợp đồng. Trễ hạn là mất cọc, xong đúng hạn mới có thưởng.',
                        style: labelStyle(size: 10.5),
                      ),
                      const SizedBox(height: 10),
                      for (final o in c.offers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OfferCard(
                            offer: o,
                            busy: c.busy,
                            money: s.money,
                            onAccept: () => _acceptContract(ctx, c, o),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.money,
    required this.onAccept,
  });

  final ContractInfo offer;
  final bool busy;
  final int money;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      borderColor: GH.gold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(offer.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
              Text('cọc ${formatMoney(offer.deposit)}',
                  style: labelStyle(size: 10, color: GH.muted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(offer.desc, style: labelStyle(size: 10.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 13, color: GH.gold),
              const SizedBox(width: 4),
              Text('+${formatMoney(offer.rewardMoney)}',
                  style: moneyStyle(size: 12)),
              const SizedBox(width: 10),
              Icon(Icons.military_tech_rounded, size: 13, color: GH.cyan),
              const SizedBox(width: 4),
              Text('+${offer.rewardUy} uy',
                  style: const TextStyle(
                      color: GH.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              SizedBox(
                width: 84,
                child: PrimaryButton(
                  label: 'NHẬN',
                  height: 32,
                  enabled: !busy && money >= offer.deposit,
                  onTap: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveContract extends StatelessWidget {
  const _ActiveContract({
    required this.contract,
    required this.busy,
    required this.onClaim,
  });

  final ContractInfo contract;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    return NeonPanel(
      color: const Color(0xFF1B1710),
      borderColor: GH.gold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              Text('còn ${_timer(c.remaining)}',
                  style: labelStyle(
                      size: 10,
                      color: c.remaining < 120 ? GH.red : GH.muted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(c.desc, style: labelStyle(size: 10.5)),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: c.ratio,
              minHeight: 4,
              backgroundColor: GH.line,
              valueColor: AlwaysStoppedAnimation(
                  c.complete ? GH.green : GH.gold),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${c.progress}/${c.target}',
                  style: labelStyle(
                      size: 10, color: c.complete ? GH.green : GH.muted)),
              const Spacer(),
              Text('+${formatMoney(c.rewardMoney)} · +${c.rewardUy} uy',
                  style: labelStyle(size: 10, color: GH.gold)),
            ],
          ),
          const SizedBox(height: 9),
          PrimaryButton(
            label: c.complete ? 'NHẬN THƯỞNG' : 'CHƯA XONG',
            height: 34,
            enabled: c.complete && !busy,
            onTap: onClaim,
          ),
        ],
      ),
    );
  }
}

Future<void> _acceptContract(
    BuildContext ctx, GameController c, ContractInfo offer) async {
  try {
    await c.acceptContract(offer.id);
    if (ctx.mounted) showToast(ctx, 'Đã nhận hợp đồng: ${offer.title}');
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}

Future<void> _claimContract(BuildContext ctx, GameController c) async {
  try {
    await c.claimContract();
    if (ctx.mounted) showToast(ctx, 'Xong hợp đồng, tiền vào túi');
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}

Future<void> showCasinoSheet(BuildContext context, GameController c) async {
  String choice = 'tai';
  int bet = 100;
  CasinoResult? result;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final s = c.state;
        if (s == null) return const SizedBox.shrink();
        final left = s.casinoLeft;
        return _sheetShell(
          heightFactor: 0.7,
          child: Column(
            children: [
              _sheetHeader(ctx, 'SÒNG BẠC',
                  trailing: Text('còn $left lượt',
                      style: labelStyle(size: 10.5))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    Text('Tài xỉu 3 xúc xắc. Tài 11–17, Xỉu 4–10, bão 3/18 nhà ăn hết. Thắng trả 1.9 lần.',
                        style: labelStyle(size: 10.5)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'TÀI',
                            height: 42,
                            color: choice == 'tai' ? GH.pink : GH.panel2,
                            onTap: () => setSheet(() => choice = 'tai'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'XỈU',
                            height: 42,
                            color: choice == 'xiu' ? GH.cyan : GH.panel2,
                            onTap: () => setSheet(() => choice = 'xiu'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final v in [100, 500, 2000]) ...[
                          Expanded(
                            child: PrimaryButton(
                              label: formatMoney(v),
                              height: 36,
                              color: bet == v ? GH.gold : GH.panel2,
                              enabled: s.money >= v,
                              onTap: () => setSheet(() => bet = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: left > 0
                          ? 'CƯỢC ${formatMoney(bet)}'
                          : 'HẾT LƯỢT HÔM NAY',
                      icon: Icons.casino_rounded,
                      height: 46,
                      enabled: left > 0 && !c.busy && s.money >= bet,
                      onTap: () async {
                        try {
                          final r = await c.playCasino(choice, bet);
                          setSheet(() => result = r);
                        } on ApiException catch (e) {
                          if (ctx.mounted) {
                            showToast(ctx, e.message, error: true);
                          }
                        }
                      },
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 16),
                      NeonPanel(
                        color: result!.win
                            ? const Color(0xFF10241C)
                            : const Color(0xFF2A1218),
                        borderColor: result!.win ? GH.green : GH.red,
                        child: Column(
                          children: [
                            Text(
                              result!.roll.join(' · '),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tổng ${result!.sum} · ${result!.win ? 'THẮNG +${formatMoney(result!.payout)}' : 'THUA'}',
                              style: TextStyle(
                                  color: result!.win ? GH.green : GH.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('Số dư: ${formatMoney(s.money)}',
                        style: labelStyle(size: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showBossSheet(BuildContext context, GameController c) async {
  try {
    await c.loadBoss();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: c,
      builder: (ctx, _) {
        final boss = c.boss;
        final s = c.state;
        if (boss == null || s == null) return const SizedBox.shrink();
        return _sheetShell(
          child: Column(
            children: [
              _sheetHeader(ctx, 'BOSS TUẦN',
                  trailing: Text(boss.week,
                      style: labelStyle(size: 10))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    NeonPanel(
                      color: const Color(0xFF1B1016),
                      borderColor: GH.red.withValues(alpha: 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.whatshot_rounded,
                                  color: GH.red, size: 20),
                              const SizedBox(width: 8),
                              const Text('ÔNG TRÙM SÀI GÒN',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900)),
                              const Spacer(),
                              Text('${boss.tickets} lượt',
                                  style: labelStyle(size: 10)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: boss.ratio,
                              minHeight: 8,
                              backgroundColor: GH.line,
                              valueColor:
                                  const AlwaysStoppedAnimation(GH.red),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            boss.defeated
                                ? 'Đã bị hạ tuần này, chờ tuần sau'
                                : '${formatMoney(boss.hp)} / ${formatMoney(boss.maxHp)} máu',
                            style: labelStyle(
                                size: 10,
                                color: boss.defeated ? GH.gold : GH.muted),
                          ),
                          const SizedBox(height: 8),
                          Text('Damage của mày: ${formatMoney(boss.myDamage)}',
                              style: labelStyle(size: 10.5)),
                          const SizedBox(height: 10),
                          PrimaryButton(
                            label: boss.defeated
                                ? 'BOSS ĐÃ BỊ HẠ'
                                : 'ĐÁNH (${boss.tickets} lượt)',
                            icon: Icons.sports_mma_rounded,
                            color: GH.red,
                            height: 40,
                            enabled: !boss.defeated &&
                                boss.tickets > 0 &&
                                !c.busy,
                            onTap: () async {
                              try {
                                final r = await c.hitBoss();
                                if (ctx.mounted) {
                                  showToast(
                                    ctx,
                                    'Gây ${formatMoney(r.damage)} dmg · +${formatMoney(r.reward)}đ',
                                  );
                                }
                              } on ApiException catch (e) {
                                if (ctx.mounted) {
                                  showToast(ctx, e.message, error: true);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('TOP DAMAGE',
                        style: labelStyle(size: 10.5, color: GH.text)),
                    const SizedBox(height: 6),
                    if (boss.top.isEmpty)
                      Text('Chưa ai đánh. Vào trước ăn top.',
                          style: labelStyle(size: 10.5))
                    else
                      for (var i = 0; i < boss.top.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        color: i == 0 ? GH.gold : GH.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Expanded(
                                child: Text(boss.top[i].name,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text(formatMoney(boss.top[i].damage),
                                  style: moneyStyle(
                                      size: 11.5, color: GH.red)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}


Future<void> _replayDefense(
  BuildContext ctx,
  GameController c,
  InboxMsg m,
) async {
  final nav = Navigator.of(ctx);
  try {
    final replay = await c.loadDefenseBattle(m.battleId);
    final s = c.state;
    if (s == null) return;
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => BrawlScreen(
        result: replay.result,
        playerName: s.name,
        myCount: (s.crew + 1).clamp(1, 5),
        myWeapon: s.weapon.name,
        enemyName: replay.attackerName,
      ),
    ));
  } on ApiException catch (e) {
    if (ctx.mounted) showToast(ctx, e.message, error: true);
  }
}

Future<void> _revenge(
  BuildContext ctx,
  GameController c,
  InboxMsg m,
) async {
  final nav = Navigator.of(ctx);
  nav.pop();
  try {
    final result = await c.attack(m.territoryId);
    final s = c.state;
    if (s == null) return;
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => BrawlScreen(
        result: result,
        playerName: s.name,
        myCount: (s.crew + 1).clamp(1, 5),
        myWeapon: s.weapon.name,
        enemyName: m.fromName.isEmpty ? 'Băng địch' : m.fromName,
      ),
    ));
    await c.reloadTerritoriesQuietly();
  } on ApiException catch (e) {
    if (nav.mounted) showToast(nav.context, e.message, error: true);
  }
}
