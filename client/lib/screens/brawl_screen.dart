import 'package:flame/game.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../scene/brawl_game.dart';
import '../theme.dart';
import '../widgets/boss_avatar.dart';
import '../widgets/common.dart';

class BrawlScreen extends StatefulWidget {
  const BrawlScreen({
    super.key,
    required this.result,
    required this.playerName,
    required this.enemyName,
    required this.myCount,
    this.myWeapon = '',
    this.bossChapter,
  });

  final BrawlResult result;
  final String playerName;
  final String enemyName;
  final int myCount;
  final String myWeapon;

  /// Có giá trị khi đánh trùm cốt truyện: hiện chân dung ở HUD trên.
  final int? bossChapter;

  @override
  State<BrawlScreen> createState() => _BrawlScreenState();
}

class _BrawlScreenState extends State<BrawlScreen> {
  late final BrawlGame _game;
  bool _done = false;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _game = BrawlGame(
      result: widget.result,
      myName: widget.playerName,
      enemyName: widget.enemyName,
      myCount: widget.myCount,
      enemyCount: 3,
      myWeapon: widget.myWeapon,
      onFinished: () {
        if (!mounted) return;
        setState(() => _done = true);
        // Giữ màn kết thúc 5s rồi tự thoát (bấm XONG vẫn thoát sớm hơn).
        _autoClose = Timer(const Duration(seconds: 5), () {
          if (mounted) Navigator.of(context).pop();
        });
      },
    );
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      backgroundColor: GH.bg,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    if (widget.bossChapter != null) ...[
                      BossAvatar(
                        chapterId: widget.bossChapter!,
                        size: 34,
                        borderColor: GH.red.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        '${widget.enemyName} · thuế ${formatMoney(r.defense)} phòng thủ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle(size: 11),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: GH.muted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_done)
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _ResultPanel(
                  result: r,
                  onDone: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.onDone});

  final BrawlResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final win = result.win;
    final color = win ? GH.gold : GH.red;
    return NeonPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      borderColor: color.withValues(alpha: 0.55),
      color: const Color(0xFF101219).withValues(alpha: 0.96),
      radius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                win
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  win
                      ? 'CHIẾM ĐƯỢC ${result.territoryLabel}'
                      : 'THUA RỒI ĐẠI CA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (win) ...[const SizedBox(height: 6), _stars(result)],
          const SizedBox(height: 10),
          _row('Lực / Phòng thủ', '${result.power} / ${result.defense}'),
          if (win)
            _row('Cướp được', '+${formatMoney(result.reward)} đ', GH.gold),
          if (result.wounded > 0)
            _row('Lính bị thương', '${result.wounded} đứa', GH.red),
          _row(
            'Uy tín',
            result.uyGain >= 0
                ? '+${formatMoney(result.uyGain)}'
                : '−${formatMoney(result.uyGain.abs())}',
            result.uyGain >= 0 ? GH.green : GH.red,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'XONG',
            icon: Icons.check_rounded,
            color: color,
            height: 44,
            onTap: onDone,
          ),
        ],
      ),
    );
  }

  Widget _stars(BrawlResult r) {
    var frac = 1.0;
    if (r.events.isNotEmpty) {
      final maxHp = r.events.first.myHp == 0 ? 1 : r.events.first.myHp;
      frac = (r.events.last.myHp / maxHp).clamp(0.0, 1.0);
    }
    final stars = frac > 0.6 ? 3 : (frac > 0.3 ? 2 : 1);
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16,
              color: i < stars ? GH.gold : GH.muted,
            ),
          ),
        const Spacer(),
        Text('${r.events.length} đòn', style: labelStyle(size: 9.5)),
      ],
    );
  }

  Widget _row(String label, String value, [Color color = GH.text]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: labelStyle(size: 12)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
