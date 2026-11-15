import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paint_utils.dart';

class BrawlGame extends FlameGame {
  BrawlGame({
    required this.result,
    required this.myName,
    required this.enemyName,
    required this.myCount,
    required this.enemyCount,
    required this.onFinished,
    this.myWeapon = '',
  });

  final BrawlResult result;
  final String myName;
  final String enemyName;
  final int myCount;
  final int enemyCount;
  final String myWeapon;
  final VoidCallback onFinished;

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    add(BrawlStage(this));
  }
}

class _Popup {
  _Popup(this.x, this.y, this.text, this.color, this.spawnAt);

  final double x;
  final double y;
  final String text;
  final Color color;
  final double spawnAt;
  static const life = 0.8;
}

class _Spark {
  _Spark(this.x, this.y, this.angle, this.color);

  final double x;
  final double y;
  final double angle;
  final Color color;
  double age = 0;
  static const life = 0.35;
}

class BrawlStage extends PositionComponent {
  BrawlStage(this.game);

  final BrawlGame game;

  int _maxMyHp = 1;
  int _maxEnemyHp = 1;
  int _hpMe = 1;
  int _hpEn = 1;
  double _ghostMe = 1;
  double _ghostEn = 1;
  int _applied = 0;
  double _elapsed = 0;
  double _t = 0;
  double _shake = 0;
  double _lungeMe = 0;
  double _lungeEn = 0;
  double _crowdFlash = 0;
  bool _done = false;
  String _koSide = '';
  double _koAt = -1;
  String _lastHitSide = '';
  double _lastHitAt = -100;
  int _comboMe = 0;
  int _comboEn = 0;
  final List<_Popup> _popups = [];
  final List<_Spark> _sparks = [];

  int get _weaponTier {
    final name = game.myWeapon;
    if (name.contains('Hàng nóng') || name.contains('Súng')) return 3;
    if (name.contains('Phớ')) return 1;
    return 0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    position = Vector2.zero();
  }

  @override
  Future<void> onLoad() async {
    final evs = game.result.events;
    if (evs.isNotEmpty) {
      _maxMyHp = math.max(evs.first.myHp, 1);
      _maxEnemyHp = math.max(evs.first.enemyHp + evs.first.dmg, 1);
      _hpMe = _maxMyHp;
      _hpEn = _maxEnemyHp;
      _ghostMe = _maxMyHp.toDouble();
      _ghostEn = _maxEnemyHp.toDouble();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done && _popups.isEmpty && _sparks.isEmpty && _elapsed > 0) return;
    _t += dt;
    _elapsed += dt * 1000;
    _shake = math.max(0, _shake - dt * 3.5);
    _lungeMe = math.max(0, _lungeMe - dt * 4);
    _lungeEn = math.max(0, _lungeEn - dt * 4);
    _crowdFlash = math.max(0, _crowdFlash - dt * 3);

    _ghostMe = math.max(_hpMe.toDouble(),
        _ghostMe - _maxMyHp * dt * (0.45 + (_maxMyHp - _hpMe) / _maxMyHp * 0.6));
    _ghostEn = math.max(_hpEn.toDouble(),
        _ghostEn - _maxEnemyHp * dt * (0.45 + (_maxEnemyHp - _hpEn) / _maxEnemyHp * 0.6));

    final evs = game.result.events;
    while (_applied < evs.length && evs[_applied].at <= _elapsed) {
      final e = evs[_applied++];
      _hpMe = e.myHp;
      _hpEn = e.enemyHp;
      final enemyX = size.x * 0.74;
      final myX = size.x * 0.26;
      if (e.side == 'me') {
        _lungeMe = 1;
        _shake = 1;
        _crowdFlash = 1;
        _comboMe = (_lastHitSide == 'me' && _elapsed - _lastHitAt < 1400)
            ? _comboMe + 1
            : 1;
        _comboEn = 0;
        _spawnSparks(enemyX, size.y * 0.56, e.crit ? GH.gold : Colors.white);
        _popups.add(_Popup(enemyX, size.y * 0.42,
            e.crit ? 'CHÍ MẠNG -${e.dmg}' : '-${e.dmg}',
            e.crit ? GH.gold : Colors.white, _elapsed));
      } else if (e.miss) {
        _shake = 0.4;
        _popups.add(_Popup(myX, size.y * 0.42, 'NÉ!', GH.cyan, _elapsed));
      } else {
        _lungeEn = 1;
        _shake = 1;
        _comboEn = (_lastHitSide == 'enemy' && _elapsed - _lastHitAt < 1400)
            ? _comboEn + 1
            : 1;
        _comboMe = 0;
        _spawnSparks(myX, size.y * 0.56, GH.red);
        _popups.add(_Popup(
            myX, size.y * 0.42, '-${e.dmg}', GH.red, _elapsed));
      }
      _lastHitSide = e.side == 'me' ? 'me' : 'enemy';
      _lastHitAt = _elapsed;
      if (_hpEn <= 0 || _hpMe <= 0) {
        _koSide = _hpEn <= 0 ? 'enemy' : 'me';
        _koAt = _elapsed;
      }
    }

    _popups.removeWhere(
        (p) => _elapsed - p.spawnAt >= _Popup.life * 1000);
    for (final s in _sparks) {
      s.age += dt;
    }
    _sparks.removeWhere((s) => s.age >= _Spark.life);

    final endAt = evs.isEmpty ? 700.0 : evs.last.at + 1300.0;
    if (!_done && _elapsed >= endAt) {
      _done = true;
      game.onFinished();
    }
  }

  void _spawnSparks(double x, double y, Color color) {
    for (var i = 0; i < 6; i++) {
      _sparks.add(_Spark(
        x + (i - 2.5) * 3,
        y + (i % 3 - 1) * 4,
        -math.pi / 2 + (i - 2.5) * 0.5,
        color,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final shakeX = _shake > 0 ? math.sin(_t * 60) * 4 * _shake : 0.0;
    final shakeY = _shake > 0 ? math.cos(_t * 47) * 3 * _shake : 0.0;
    canvas.save();
    canvas.translate(shakeX, shakeY);

    _background(canvas, w, h);
    final ground = h * 0.78;

    final koTime = _koAt < 0 ? 0.0 : ((_elapsed - _koAt) / 500).clamp(0.0, 1.0);

    for (var i = game.enemyCount - 1; i >= 0; i--) {
      final standing = (_hpEn / _maxEnemyHp * game.enemyCount)
          .ceil()
          .clamp(0, game.enemyCount);
      final isLeader = i == 0;
      if (i >= standing && !(isLeader && _koSide == 'enemy')) continue;
      final falling = isLeader && _koSide == 'enemy' ? koTime : 0.0;
      _fighter(
        canvas,
        Offset(w * 0.74 + i * w * 0.05, ground),
        h * (isLeader ? 0.19 : 0.14),
        GH.red,
        faceRight: false,
        lunge: isLeader ? _lungeEn : 0,
        backlight: isLeader,
        koTilt: falling,
        victory: isLeader && _koSide == 'me' && koTime > 0.5,
        weaponTier: 0,
      );
    }

    for (var i = game.myCount - 1; i >= 0; i--) {
      final standing = (_hpMe / _maxMyHp * game.myCount)
          .ceil()
          .clamp(0, game.myCount);
      final isLeader = i == 0;
      if (i >= standing && !(isLeader && _koSide == 'me')) continue;
      final falling = isLeader && _koSide == 'me' ? koTime : 0.0;
      _fighter(
        canvas,
        Offset(w * 0.26 - i * w * 0.05, ground),
        h * (isLeader ? 0.2 : 0.14),
        GH.cyan,
        faceRight: true,
        lunge: isLeader ? _lungeMe : 0,
        backlight: isLeader,
        koTilt: falling,
        victory: isLeader && _koSide == 'enemy' && koTime > 0.5,
        weaponTier: isLeader ? _weaponTier : 0,
      );
    }

    for (final s in _sparks) {
      final k = (s.age / _Spark.life).clamp(0.0, 1.0);
      final len = 12 * (1 - k);
      final dx = math.cos(s.angle) * len;
      final dy = math.sin(s.angle) * len;
      canvas.drawLine(
        Offset(s.x, s.y + k * 10),
        Offset(s.x + dx, s.y + k * 10 + dy),
        Paint()
          ..color = s.color.withValues(alpha: 1 - k)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final p in _popups) {
      final age = (_elapsed - p.spawnAt) / 1000;
      final k = (age / _Popup.life).clamp(0.0, 1.0);
      paintText(
        canvas,
        p.text,
        Offset(p.x, p.y - k * 48),
        size: (p.text.length > 5 ? 19 : 24) - k * 6,
        color: p.color.withValues(alpha: 1 - k),
        weight: FontWeight.w900,
        align: TextAlign.center,
        glow: p.color.withValues(alpha: (1 - k) * 0.6),
        glowBlur: 12,
      );
    }

    _combo(canvas, w, h);
    _bars(canvas, w, h);

    if (koTime > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Colors.black.withValues(alpha: 0.28 * koTime),
      );
    }
    if (koTime > 0.25) {
      paintText(
        canvas,
        'K.O.',
        Offset(w / 2, h * 0.24),
        size: 58,
        color: GH.gold,
        weight: FontWeight.w900,
        align: TextAlign.center,
        glow: GH.gold.withValues(alpha: 0.8),
        glowBlur: 30,
      );
    }

    if (_done) {
      final win = game.result.win;
      paintText(
        canvas,
        win ? 'THẮNG' : 'BỊ ĐẬP',
        Offset(w / 2, h * 0.33),
        size: 40,
        color: win ? GH.gold : GH.red,
        weight: FontWeight.w900,
        align: TextAlign.center,
        glow: (win ? GH.gold : GH.red).withValues(alpha: 0.7),
        glowBlur: 22,
      );
    }

    canvas.restore();
  }

  void _combo(Canvas c, double w, double h) {
    final activeMe = _comboMe >= 2 && _elapsed - _lastHitAt < 1200;
    final activeEn = _comboEn >= 2 && _elapsed - _lastHitAt < 1200;
    if (!activeMe && !activeEn) return;
    final combo = activeMe ? _comboMe : _comboEn;
    final color = activeMe ? GH.cyan : GH.red;
    final x = activeMe ? w * 0.3 : w * 0.7;
    paintText(
      c,
      'x$combo COMBO',
      Offset(x, h * 0.34),
      size: 20,
      color: color,
      weight: FontWeight.w900,
      align: TextAlign.center,
      glow: color.withValues(alpha: 0.6),
      glowBlur: 10,
    );
  }

  void _bars(Canvas c, double w, double h) {
    final barW = w * 0.36;
    _hpBar(
      c,
      Rect.fromLTWH(w * 0.05, 52, barW, 13),
      _hpMe / _maxMyHp,
      _ghostMe / _maxMyHp,
      GH.cyan,
      game.myName,
      '$_hpMe',
    );
    _hpBar(
      c,
      Rect.fromLTWH(w - w * 0.05 - barW, 52, barW, 13),
      _hpEn / _maxEnemyHp,
      _ghostEn / _maxEnemyHp,
      GH.red,
      game.enemyName,
      '$_hpEn',
      right: true,
    );
    paintText(
      c,
      'VS',
      Offset(w / 2, 28),
      size: 13,
      color: Colors.white.withValues(alpha: 0.5),
      weight: FontWeight.w900,
      align: TextAlign.center,
    );
  }

  void _background(Canvas c, double w, double h) {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0910), Color(0xFF1C0F1E), Color(0xFF08090D)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Hanging lamp + light cone.
    final lampX = w * 0.5;
    c.drawLine(
      Offset(lampX, 0),
      Offset(lampX, h * 0.1),
      Paint()
        ..color = const Color(0xFF2A2230)
        ..strokeWidth = 2,
    );
    final cone = Path()
      ..moveTo(lampX - 10, h * 0.1)
      ..lineTo(lampX + 10, h * 0.1)
      ..lineTo(lampX + w * 0.34, h * 0.78)
      ..lineTo(lampX - w * 0.34, h * 0.78)
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
        ).createShader(Rect.fromLTWH(0, h * 0.1, w, h * 0.68)),
    );
    paintGlowCircle(c, Offset(lampX, h * 0.1), 5,
        const Color(0xFFFFE6AE), blur: 18);

    paintText(
      c,
      'SỚI GÀ',
      Offset(w / 2, h * 0.125),
      size: 58,
      color: Colors.white.withValues(alpha: 0.045),
      weight: FontWeight.w900,
      align: TextAlign.center,
    );

    final brick = Paint()..color = const Color(0xFF120F18);
    final mortar = Paint()..color = const Color(0xFF19141F);
    for (var y = h * 0.2; y < h * 0.72; y += 22) {
      for (var x = -8.0; x < w; x += 46) {
        final offset = ((y ~/ 22) % 2 == 0) ? 0.0 : 23.0;
        final r = Rect.fromLTWH(x + offset, y, 42, 18);
        c.drawRect(r, brick);
        c.drawRect(
            Rect.fromLTWH(r.left, r.bottom - 2, r.width, 2), mortar);
      }
    }

    final groundY = h * 0.78;
    c.drawRect(
      Rect.fromLTWH(0, groundY, w, h - groundY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF18141F), Color(0xFF08080C)],
        ).createShader(Rect.fromLTWH(0, groundY, w, h - groundY)),
    );
    c.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = GH.pink.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );

    // Crowd silhouettes with phone flashes.
    for (var i = 0; i < 11; i++) {
      final x = (i / 10) * w;
      final bob = math.sin(_t * 2 + i) * 1.5;
      final y = h * 0.735 + bob;
      final dark = Paint()
        ..color = const Color(0xFF0A0A0F).withValues(alpha: 0.9);
      c.drawCircle(Offset(x, y), 8, dark);
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 7, y + 6, 14, h * 0.045),
            const Radius.circular(4)),
        dark,
      );
      if (_crowdFlash > 0 && i % 4 == 1) {
        c.drawCircle(
          Offset(x + 5, y - 4),
          2.2,
          Paint()
            ..color = Colors.white.withValues(alpha: _crowdFlash * 0.8),
        );
      }
    }

    // Vignette.
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Color(0x88000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _hpBar(Canvas c, Rect rect, double frac, double ghost, Color color,
      String name, String hp,
      {bool right = false}) {
    paintRoundedRect(c, rect, const Color(0xFF141721),
        radius: 7, border: GH.line);
    final g = ghost.clamp(0.0, 1.0);
    if (g > 0.01) {
      paintRoundedRect(
        c,
        Rect.fromLTWH(
            rect.left + 2, rect.top + 2, (rect.width - 4) * g, rect.height - 4),
        Colors.white.withValues(alpha: 0.25),
        radius: 5,
      );
    }
    final f = frac.clamp(0.0, 1.0);
    final innerW = (rect.width - 4) * f;
    if (innerW > 1) {
      paintRoundedRect(
        c,
        Rect.fromLTWH(rect.left + 2, rect.top + 2, innerW, rect.height - 4),
        color,
        radius: 5,
      );
      c.drawRect(
        Rect.fromLTWH(rect.left + 2, rect.top + 2, innerW, 2),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    paintText(
      c,
      name,
      Offset(right ? rect.right : rect.left, rect.top - 16),
      size: 10.5,
      color: GH.text,
      weight: FontWeight.w800,
      align: right ? TextAlign.right : TextAlign.left,
    );
    paintText(
      c,
      hp,
      Offset(rect.center.dx, rect.top + 1),
      size: 9,
      color: Colors.white.withValues(alpha: 0.9),
      align: TextAlign.center,
    );
  }

  void _fighter(
    Canvas c,
    Offset pos,
    double s,
    Color accent, {
    required bool faceRight,
    double lunge = 0,
    bool backlight = false,
    double koTilt = 0,
    bool victory = false,
    int weaponTier = 0,
  }) {
    c.save();
    c.translate(
      pos.dx + (faceRight ? lunge * 20 : -lunge * 20),
      pos.dy + math.sin(_t * 4 + pos.dx * 0.05) * 1.5,
    );
    c.scale(faceRight ? 1 : -1, 1);
    if (koTilt > 0) {
      c.rotate(koTilt * 1.35);
    }

    c.drawOval(
      Rect.fromCenter(
          center: const Offset(0, 2), width: s * 0.9, height: s * 0.14),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final leg = Paint()..color = const Color(0xFF111319);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-s * 0.26, -s * 0.52, s * 0.19, s * 0.52),
          Radius.circular(s * 0.06)),
      leg,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.06, -s * 0.52, s * 0.19, s * 0.52),
          Radius.circular(s * 0.06)),
      leg,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(-s * 0.34, -s * 1.22, s * 0.68, s * 0.74),
      Radius.circular(s * 0.17),
    );
    if (backlight) {
      paintGlowCircle(c, Offset(0, -s * 0.8), s * 0.55,
          accent.withValues(alpha: 0.07), blur: 18);
    }
    c.drawRRect(body, Paint()..color = const Color(0xFF191C26));
    c.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..color = accent.withValues(alpha: 0.38),
    );
    c.drawRect(
      Rect.fromLTWH(-s * 0.05, -s * 1.18, s * 0.1, s * 0.66),
      Paint()..color = accent.withValues(alpha: 0.55),
    );

    final arm = Paint()..color = const Color(0xFF141721);
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-s * 0.46, -s * 1.14, s * 0.16, s * 0.58),
          Radius.circular(s * 0.08)),
      arm,
    );
    if (victory) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.34, -s * 1.72, s * 0.15, s * 0.6),
            Radius.circular(s * 0.08)),
        arm,
      );
      c.drawCircle(
          Offset(s * 0.41, -s * 1.75), s * 0.09,
          Paint()..color = const Color(0xFFC98A63));
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.42, -s * 1.14, s * 0.16, s * 0.58),
            Radius.circular(s * 0.08)),
        arm,
      );
    }

    c.drawCircle(Offset(0, -s * 1.42), s * 0.24,
        Paint()..color = const Color(0xFFC98A63));
    c.drawArc(
      Rect.fromCircle(center: Offset(0, -s * 1.45), radius: s * 0.25),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF0C0D12),
    );
    c.drawRect(
      Rect.fromLTWH(-s * 0.18, -s * 1.47, s * 0.36, s * 0.08),
      Paint()..color = const Color(0xFF08090C),
    );

    // Weapon in right hand.
    if (weaponTier >= 2) {
      final gun = Paint()..color = const Color(0xFF2C313D);
      c.drawRect(
          Rect.fromLTWH(s * 0.46, -s * 0.9, s * 0.24, s * 0.08), gun);
      c.drawRect(
          Rect.fromLTWH(s * 0.46, -s * 0.9, s * 0.07, s * 0.16), gun);
    } else {
      final blade = Path()
        ..moveTo(s * 0.46, -s * 0.86)
        ..lineTo(s * 0.68, -s * 1.02)
        ..lineTo(s * 0.72, -s * 0.97)
        ..lineTo(s * 0.5, -s * 0.8)
        ..close();
      c.drawPath(
          blade, Paint()..color = const Color(0xFFB8C0CF));
      c.drawRect(
        Rect.fromLTWH(s * 0.44, -s * 0.9, s * 0.05, s * 0.12),
        Paint()..color = const Color(0xFF3A2A20),
      );
    }

    c.restore();
  }
}
