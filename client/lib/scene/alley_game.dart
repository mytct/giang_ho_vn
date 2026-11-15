import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paint_utils.dart';
import 'scene_image.dart';

class AlleyGame extends FlameGame {
  AlleyGame({required this.rate});

  double rate;

  void setRate(double value) => rate = value;

  late final ui.Image bg;
  final Map<String, ui.Image> _minionFrames = {};

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    bg = await loadSceneImage('bg_alley');
    for (final name in ['idle1', 'idle2', 'run1', 'run2', 'run3', 'run4']) {
      try {
        _minionFrames[name] = await loadFightFrame('p_$name');
      } catch (_) {
        break;
      }
    }
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
  double _walkerX = 0.7;

  static const _standSpots = [
    (0.15, 0.95, 210.0, 0.0),
    (0.32, 0.94, 196.0, 1.3),
    (0.55, 0.955, 222.0, 2.1),
  ];

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
    _spawn += dt;
    _walkerX += dt * 0.045;
    if (_walkerX > 1.08) {
      _walkerX = -0.08; // đi hết hẻm rồi vào lại từ đầu, không bounce
    }
    if (_spawn >= 0.8) {
      _spawn = 0;
      _coins.add(
        _Coin(
          x: size.x * (0.12 + _rnd.nextDouble() * 0.76),
          y: size.y * (0.62 + _rnd.nextDouble() * 0.14),
          text: '+${formatMoney(game.rate)}/s',
          life: 2.2,
          drift: 16 + _rnd.nextDouble() * 16,
        ),
      );
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

    // Ảnh hẻm làm nền, neo đáy để mặt đường luôn nằm dưới chân khung.
    final img = game.bg;
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = math.max(w / iw, h / ih);
    // Nhích zoom rất chậm để khung hình không chết cứng.
    final zoom = 1.0 + 0.015 * (math.sin(_t * 0.3) + 1) / 2;
    final dw = iw * scale * zoom;
    final dh = ih * scale * zoom;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.42, w, h * 0.58),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0007080C), Color(0xC907080C)],
        ).createShader(Rect.fromLTWH(0, h * 0.42, w, h * 0.58)),
    );

    _drawMinions(canvas, w, h);

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

  void _drawMinions(Canvas canvas, double w, double h) {
    final frames = game._minionFrames;
    if (frames.isEmpty) return;

    ui.Image? idleFrame(double phase) {
      final idx = (((_t / 0.45) + phase) % 2).floor() + 1;
      return frames['idle$idx'];
    }

    for (final (fx, fy, fh, phase) in _standSpots) {
      final img = idleFrame(phase);
      if (img == null) continue;
      _drawSprite(
        canvas,
        img,
        cx: w * fx,
        footY: h * fy,
        height: fh,
        flip: phase > 1.5,
      );
    }

    final runIdx = (((_t / 0.12) % 4)).floor() + 1;
    final walker = frames['run$runIdx'];
    if (walker != null) {
      _drawSprite(
        canvas,
        walker,
        cx: w * _walkerX,
        footY: h * 0.99,
        height: 252,
        flip: false,
      );
    }
  }

  void _drawSprite(
    Canvas canvas,
    ui.Image img, {
    required double cx,
    required double footY,
    required double height,
    required bool flip,
  }) {
    final dw = height * img.width / img.height;
    canvas.save();
    canvas.translate(cx, footY);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-dw / 2, -height, dw, height),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }
}
