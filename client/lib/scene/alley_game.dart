import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paint_utils.dart';

class AlleyGame extends FlameGame {
  AlleyGame({required this.rate, this.crew = 0});

  double rate;
  int crew;

  void setRate(double value) => rate = value;

  void setCrew(int value) => crew = value;

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    add(AlleyArt(this));
  }
}

class _Coin {
  _Coin({
    required this.x,
    required this.y,
    required this.text,
    required this.life,
    required this.drift,
  });

  double x;
  double y;
  final String text;
  double life;
  final double drift;
}

class AlleyArt extends PositionComponent {
  AlleyArt(this.game);

  final AlleyGame game;
  final math.Random _rnd = math.Random(11);
  final List<_Coin> _coins = [];
  double _t = 0;
  double _spawn = 0;
  double _signPulse = 0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0 || size.y <= 0) return;
    _t += dt;
    _signPulse = (math.sin(_t * 2.2) + 1) / 2;
    _spawn += dt;
    if (_spawn >= 0.8) {
      _spawn = 0;
      _coins.add(_Coin(
        x: size.x * (0.12 + _rnd.nextDouble() * 0.76),
        y: size.y * (0.62 + _rnd.nextDouble() * 0.14),
        text: '+${formatMoney(game.rate)}/s',
        life: 2.2,
        drift: 16 + _rnd.nextDouble() * 16,
      ));
    }
    for (final c in _coins) {
      c.y -= c.drift * dt;
      c.life -= dt;
    }
    _coins.removeWhere((c) => c.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0C0E1A), Color(0xFF1C0F22), Color(0xFF08090E)],
        stops: [0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    paintGlowCircle(canvas, Offset(w * 0.84, h * 0.19), h * 0.045,
        const Color(0xFFFFE6AE).withValues(alpha: 0.55), blur: 16);
    canvas.drawCircle(Offset(w * 0.84, h * 0.19), h * 0.035,
        Paint()..color = const Color(0xFFFFF1C9).withValues(alpha: 0.9));

    _buildings(canvas, w, h);

    final signGlow = 0.45 + _signPulse * 0.35;
    _sign(canvas, 'KARAOKE', w * 0.22, h * 0.36, GH.pink, w * 0.26, signGlow);
    _sign(canvas, 'MATXA', w * 0.52, h * 0.29, GH.cyan, w * 0.2,
        1 - signGlow * 0.5);
    _sign(canvas, 'NHẬU', w * 0.79, h * 0.4, GH.gold, w * 0.18, signGlow);

    final ground = h * 0.9;
    _lamp(canvas, w, h, ground);
    _extraCrew(canvas, w, h, ground);
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF14131A), Color(0xFF0A0A0F)],
      ).createShader(Rect.fromLTWH(0, ground, w, h - ground));
    canvas.drawRect(Rect.fromLTWH(0, ground, w, h - ground), groundPaint);
    canvas.drawLine(
      Offset(0, ground),
      Offset(w, ground),
      Paint()
        ..strokeWidth = 1.2
        ..color = GH.pink.withValues(alpha: 0.25),
    );

    final s = h * 0.23;
    _gangster(canvas, w * 0.28, ground, s, GH.pink, _t * 1.6);
    _gangster(canvas, w * 0.5, ground, s * 1.12, GH.gold, _t * 1.6 + 1.3,
        hasGun: true);
    _gangster(canvas, w * 0.72, ground, s, GH.cyan, _t * 1.6 + 2.4);

    _smoke(canvas, w, h);
    _hideout(canvas, w, h, ground);
    _vignette(canvas, w, h);

    for (final c in _coins) {
      final a = (c.life / 2.2).clamp(0.0, 1.0);
      paintText(
        canvas,
        c.text,
        Offset(c.x, c.y),
        size: 11,
        color: GH.gold.withValues(alpha: a),
        weight: FontWeight.w800,
        align: TextAlign.center,
        glow: GH.gold.withValues(alpha: a * 0.7),
      );
    }
  }

  void _lamp(Canvas c, double w, double h, double ground) {
    final x = w * 0.5;
    c.drawLine(
      Offset(x, 0),
      Offset(x, h * 0.12),
      Paint()
        ..color = const Color(0xFF2A2230)
        ..strokeWidth = 1.5,
    );
    final cone = Path()
      ..moveTo(x - 7, h * 0.12)
      ..lineTo(x + 7, h * 0.12)
      ..lineTo(x + w * 0.28, ground)
      ..lineTo(x - w * 0.28, ground)
      ..close();
    c.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFC93C).withValues(alpha: 0.10),
            const Color(0xFFFFC93C).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.12, w, ground - h * 0.12)),
    );
    paintGlowCircle(
        c, Offset(x, h * 0.12), 4, const Color(0xFFFFE6AE), blur: 14);
  }

  void _extraCrew(Canvas c, double w, double h, double ground) {
    final count = math.min(game.crew, 3);
    for (var i = 0; i < count; i++) {
      final x = w * (0.34 + i * 0.13);
      final s = h * 0.16;
      final paint = Paint()..color = const Color(0xFF161922);
      final bob = math.sin(_t * 1.4 + i) * 1.2;
      c.drawOval(
        Rect.fromCenter(
            center: Offset(x, ground - 2), width: s * 0.8, height: s * 0.14),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - s * 0.28, ground - s * 1.05 + bob,
                s * 0.56, s * 0.62),
            Radius.circular(s * 0.16)),
        paint,
      );
      c.drawCircle(
        Offset(x, ground - s * 1.2 + bob),
        s * 0.18,
        Paint()..color = const Color(0xFF9E7250),
      );
      c.drawRect(
        Rect.fromLTWH(x - s * 0.15, ground - s * 1.24 + bob, s * 0.3,
            s * 0.06),
        Paint()..color = const Color(0xFF08090C),
      );
    }
  }

  void _smoke(Canvas c, double w, double h) {
    for (var i = 0; i < 4; i++) {
      final phase = (_t * 0.5 + i * 0.23) % 1;
      final x = w * 0.5 + math.sin(_t * 0.9 + i) * 5;
      final y = h * 0.52 - phase * h * 0.22;
      c.drawCircle(
        Offset(x, y),
        2.5 + phase * 3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05 * (1 - phase)),
      );
    }
  }

  void _hideout(Canvas c, double w, double h, double ground) {
    // Bàn nhậu + chai bia ở góc trái.
    final tableTop = ground + h * 0.02;
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.03, tableTop, w * 0.26, h * 0.05),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF241A14),
    );
    c.drawRect(
      Rect.fromLTWH(w * 0.05, tableTop + h * 0.05, 3, h * 0.04),
      Paint()..color = const Color(0xFF1A120E),
    );
    c.drawRect(
      Rect.fromLTWH(w * 0.25, tableTop + h * 0.05, 3, h * 0.04),
      Paint()..color = const Color(0xFF1A120E),
    );
    for (var i = 0; i < 3; i++) {
      final bx = w * (0.07 + i * 0.06);
      c.drawRect(
        Rect.fromLTWH(bx, tableTop - h * 0.035, w * 0.012, h * 0.035),
        Paint()..color = const Color(0xFF1E5E3A),
      );
      c.drawRect(
        Rect.fromLTWH(bx + w * 0.003, tableTop - h * 0.05, w * 0.006,
            h * 0.016),
        Paint()..color = const Color(0xFF2C7A4C),
      );
    }
    // Thùng bia bên phải.
    c.drawRect(
      Rect.fromLTWH(w * 0.76, ground - h * 0.055, w * 0.1, h * 0.055),
      Paint()..color = const Color(0xFF2A1F16),
    );
    c.drawRect(
      Rect.fromLTWH(w * 0.765, ground - h * 0.05, w * 0.09, h * 0.02),
      Paint()..color = const Color(0xFF3A2A1C),
    );
  }

  void _vignette(Canvas c, double w, double h) {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Color(0x99000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _buildings(Canvas c, double w, double h) {
    final paint = Paint()..color = const Color(0xFF0D0F17);
    final win = Paint()..color = const Color(0xFFFFC93C).withValues(alpha: 0.18);
    final rects = <Rect>[
      Rect.fromLTWH(0, h * 0.36, w * 0.34, h * 0.5),
      Rect.fromLTWH(w * 0.36, h * 0.28, w * 0.3, h * 0.58),
      Rect.fromLTWH(w * 0.68, h * 0.4, w * 0.32, h * 0.46),
    ];
    for (final r in rects) {
      c.drawRect(r, paint);
      for (var y = r.top + 10; y < r.bottom - 8; y += 18) {
        for (var x = r.left + 8; x < r.right - 8; x += 20) {
          c.drawRect(Rect.fromLTWH(x, y, 6, 8), win);
        }
      }
    }
    final wire = Paint()
      ..color = const Color(0xFF1B1E28)
      ..strokeWidth = 1;
    c.drawLine(Offset(0, h * 0.22), Offset(w * 0.5, h * 0.3), wire);
    c.drawLine(Offset(w * 0.5, h * 0.3), Offset(w, h * 0.2), wire);
  }

  void _sign(Canvas c, String text, double cx, double y, Color color,
      double width, double glow) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: width, height: 24),
      const Radius.circular(7),
    );
    c.drawRRect(
      rect,
      Paint()..color = const Color(0xFF07080D).withValues(alpha: 0.9),
    );
    c.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.55 + glow * 0.4),
    );
    paintText(
      c,
      text,
      Offset(cx, y - 7),
      size: 10,
      color: color,
      weight: FontWeight.w900,
      align: TextAlign.center,
      glow: color.withValues(alpha: 0.35 + glow * 0.5),
      glowBlur: 10,
    );
  }

  void _gangster(Canvas c, double x, double ground, double s, Color accent,
      double phase,
      {bool hasGun = false}) {
    final y = ground + math.sin(phase) * s * 0.02;
    final shadow = Rect.fromCenter(
      center: Offset(x, ground + 3),
      width: s * 1.1,
      height: s * 0.16,
    );
    c.drawOval(shadow, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final leg = Paint()..color = const Color(0xFF12141C);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - s * 0.28, y - s * 0.56, s * 0.21, s * 0.56),
          Radius.circular(s * 0.07)),
      leg,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + s * 0.07, y - s * 0.56, s * 0.21, s * 0.56),
          Radius.circular(s * 0.07)),
      leg,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - s * 0.38, y - s * 1.3, s * 0.76, s * 0.8),
      Radius.circular(s * 0.19),
    );
    c.drawRRect(body, Paint()..color = const Color(0xFF1A1D27));
    c.drawRect(
      Rect.fromLTWH(x - s * 0.055, y - s * 1.26, s * 0.11, s * 0.72),
      Paint()..color = accent.withValues(alpha: 0.5),
    );

    final arm = Paint()..color = const Color(0xFF151822);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - s * 0.51, y - s * 1.22, s * 0.17, s * 0.62),
          Radius.circular(s * 0.08)),
      arm,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x + s * 0.34, y - s * 1.22, s * 0.17, s * 0.62),
          Radius.circular(s * 0.08)),
      arm,
    );

    c.drawCircle(Offset(x, y - s * 1.51), s * 0.26,
        Paint()..color = const Color(0xFFC98A63));
    c.drawArc(
      Rect.fromCircle(center: Offset(x, y - s * 1.54), radius: s * 0.27),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF0D0E13),
    );
    c.drawRect(
      Rect.fromLTWH(x - s * 0.2, y - s * 1.56, s * 0.4, s * 0.09),
      Paint()..color = const Color(0xFF08090C),
    );

    if (hasGun) {
      final gun = Paint()..color = const Color(0xFF2B2F3C);
      c.drawRect(
        Rect.fromLTWH(x + s * 0.44, y - s * 0.78, s * 0.22, s * 0.07),
        gun,
      );
      c.drawRect(
        Rect.fromLTWH(x + s * 0.44, y - s * 0.78, s * 0.06, s * 0.15),
        gun,
      );
    }
  }
}
