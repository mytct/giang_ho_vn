import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showDiplomacySheet(
    BuildContext context, GameController c) async {
  try {
    await c.loadDiplomacy();
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
        final mine = c.state?.gangId ?? '';
        final names = <String, String>{
          for (final g in c.gangs) g.id: g.name,
        };
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: Container(
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(
                      children: [
                        const Text('SƠ ĐỒ NGOẠI GIAO',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: GH.muted, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _legend(GH.green, 'Liên minh'),
                        const SizedBox(width: 12),
                        _legend(GH.red, 'Chiến'),
                        const SizedBox(width: 12),
                        _legend(GH.gold, 'Cống nộp'),
                        const Spacer(),
                        Text('${c.gangs.length} băng',
                            style: labelStyle(size: 10)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 290,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: DiplomacyPainter(
                        gangs: c.gangs,
                        edges: c.edges,
                        myGangId: mine,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Row(
                      children: [
                        Text('DANH SÁCH QUAN HỆ',
                            style: labelStyle(size: 10.5, color: GH.text)),
                        const Spacer(),
                        Text('${c.edges.length} cạnh',
                            style: labelStyle(size: 9.5)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: c.edges.isEmpty
                        ? Center(
                            child: Text('Chưa có quan hệ nào giữa các băng',
                                style: labelStyle(size: 11.5)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemCount: c.edges.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final e = c.edges[i];
                              final color = e.kind == 'war'
                                  ? GH.red
                                  : (e.kind == 'ally' ? GH.green : GH.gold);
                              final label = e.kind == 'war'
                                  ? 'ĐANG CHIẾN'
                                  : (e.kind == 'ally'
                                      ? 'LIÊN MINH'
                                      : 'NỘP CỐNG');
                              final extra = e.kind == 'tribute'
                                  ? ''
                                  : ' · ${_remaining(e.until)}';
                              return NeonPanel(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                borderColor: color.withValues(alpha: 0.35),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${names[e.from] ?? '?'} → ${names[e.to] ?? '?'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text('$label$extra',
                                        style: labelStyle(
                                            size: 9, color: color)),
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
        );
      },
    ),
  );
}

Widget _legend(Color color, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 3,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 4),
      Text(text, style: labelStyle(size: 9.5)),
    ],
  );
}

String _remaining(int untilUnix) {
  final left = untilUnix - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (left <= 0) return 'hết';
  if (left >= 86400) return '${(left / 86400).ceil()} ngày';
  if (left >= 3600) return '${(left / 3600).ceil()} giờ';
  return '${(left / 60).ceil()} phút';
}

class DiplomacyPainter extends CustomPainter {
  DiplomacyPainter({
    required this.gangs,
    required this.edges,
    required this.myGangId,
  });

  final List<GangInfo> gangs;
  final List<RelationEdge> edges;
  final String myGangId;

  @override
  void paint(Canvas canvas, Size size) {
    if (gangs.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width, size.height) / 2 - 42;
    final pos = <String, Offset>{};
    for (var i = 0; i < gangs.length; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / gangs.length;
      pos[gangs[i].id] =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    for (final e in edges) {
      final a = pos[e.from];
      final b = pos[e.to];
      if (a == null || b == null) continue;
      final color = e.kind == 'war'
          ? GH.red
          : (e.kind == 'ally' ? GH.green : GH.gold);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..strokeWidth = e.kind == 'war' ? 2 : 1.4,
      );
      if (e.kind == 'tribute') {
        final dir = b - a;
        final len = dir.distance;
        if (len > 1) {
          final unit = dir / len;
          final tip = b - unit * 22;
          final side = Offset(-unit.dy, unit.dx) * 5;
          final path = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((tip - unit * 8 + side).dx, (tip - unit * 8 + side).dy)
            ..lineTo((tip - unit * 8 - side).dx, (tip - unit * 8 - side).dy)
            ..close();
          canvas.drawPath(path, Paint()..color = GH.gold);
        }
      }
    }

    for (final g in gangs) {
      final p = pos[g.id]!;
      final tierColor =
          g.tier == 1 ? GH.gold : (g.tier == 2 ? GH.cyan : GH.muted);
      final isMe = g.id == myGangId;
      canvas.drawCircle(p, 17, Paint()..color = GH.panel2);
      canvas.drawCircle(
        p,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isMe ? 3 : 1.6
          ..color = isMe ? GH.pink : tierColor,
      );
      _label(canvas, 'T${g.tier}', p + const Offset(0, -6), 9.5, tierColor);
      _label(
        canvas,
        g.name,
        p + const Offset(0, 22),
        8.5,
        isMe ? GH.pink : GH.text,
        maxWidth: 92,
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, double size, Color color,
      {double maxWidth = 40}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant DiplomacyPainter oldDelegate) => true;
}
