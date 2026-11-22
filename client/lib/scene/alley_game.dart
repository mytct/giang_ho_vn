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

  /// Pool atlas 4×4 nhân vật: p, e và 12 biến thể minion.
  static const atlasPool = [
    'atlas_p',
    'atlas_e',
    'atlas_m1',
    'atlas_m2',
    'atlas_m3',
    'atlas_m4',
    'atlas_m5',
    'atlas_m6',
    'atlas_m7',
    'atlas_m8',
    'atlas_m9',
    'atlas_m10',
    'atlas_m11',
    'atlas_m12',
  ];

  /// Dàn nhân vật ở sân: mỗi lần vào app cast ngẫu nhiên (atlas + sắc độ).
  final List<ui.Image> cast = [];

  /// Thứ tự ô trong atlas 4×4 (khớp FightFrames.slots).
  static const slots = [
    'run1',
    'run2',
    'run3',
    'run4',
    'idle1',
    'idle2',
    'atk1',
    'atk2',
    'hurt',
    'ko1',
    'ko2',
    'win',
    'gun1',
    'gun2',
    'aim',
    'fire',
  ];

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    bg = await loadSceneImage('bg_alley');
    final names = [...atlasPool]..shuffle();
    for (final n in names.take(6)) {
      try {
        cast.add(await loadFightFrame(n));
      } catch (_) {}
    }
    if (cast.isEmpty) {
      try {
        cast.add(await loadFightFrame('atlas_p'));
      } catch (_) {}
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
  AlleyArt(this.game) {
    // Mỗi lần mở app: cast, vị trí, dáng đứng, tốc độ đi đều ngẫu nhiên.
    // Đàn em đứng YÊN: mỗi đứa đóng 1 pose idle ngẫu nhiên, không nhúc nhích.
    final cast = game.cast;
    for (var i = 0; i < _standSpots.length; i++) {
      _crowd.add((
        img: cast.isEmpty ? null : cast[i % cast.length],
        tint: _randomTint(),
        xJit: (_rnd.nextDouble() - 0.5) * 0.06,
        hMul: 0.88 + _rnd.nextDouble() * 0.26,
        frame: 'idle${1 + _rnd.nextInt(2)}',
        flip: _rnd.nextBool(),
      ));
    }
    _walker = (
      img: cast.isEmpty ? null : cast[cast.length > 5 ? 5 : 0],
      tint: _randomTint(),
      speed: 0.035 + _rnd.nextDouble() * 0.03,
      dir: _rnd.nextBool() ? 1 : -1,
    );
  }

  final AlleyGame game;
  final math.Random _rnd = math.Random();
  final List<_Coin> _coins = [];
  final List<({ui.Image? img, Color tint, double xJit, double hMul, String frame, bool flip})>
      _crowd = [];
  late ({ui.Image? img, Color tint, double speed, int dir}) _walker;
  double _t = 0;
  double _spawn = 0;
  double _walkDist = 0;
  double _walkerX = _rnd2.nextDouble() * 1.1 - 0.05;

  static final math.Random _rnd2 = math.Random();

  /// Sắc độ áo quần ngẫu nhiên: wash màu nhẹ lên sprite để mỗi em một vẻ.
  /// Trộn với trắng giữ alpha 1 — modulate nhân cả alpha, tint mờ trong
  /// suốt là hư sprite.
  static const _tints = [
    Color(0xFFFF6D5A), // đỏ gạch
    Color(0xFF5AC8FF), // xanh băng
    Color(0xFF7DFF8A), // xanh lá
    Color(0xFFFFD24A), // vàng kim
    Color(0xFFC77DFF), // tím than
    Color(0xFFFF9DE0), // hồng phấn
  ];

  Color _randomTint() =>
      Color.lerp(const Color(0xFFFFFFFF), _tints[_rnd.nextInt(_tints.length)], 0.28)!;

  static const _standSpots = [
    (0.05, 0.945, 198.0),
    (0.15, 0.95, 210.0),
    (0.32, 0.94, 196.0),
    (0.44, 0.935, 188.0),
    (0.55, 0.955, 222.0),
    (0.68, 0.945, 200.0),
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
    _walkerX += dt * _walker.speed * _walker.dir;
    _walkDist += dt * _walker.speed; // đo quãng đường để khớp bước chân
    if (_walkerX > 1.08) {
      _walkerX = 1.08;
      _walker = (
        img: _walker.img,
        tint: _walker.tint,
        speed: _walker.speed,
        dir: -1,
      );
    } else if (_walkerX < -0.08) {
      _walkerX = -0.08;
      _walker = (
        img: _walker.img,
        tint: _walker.tint,
        speed: _walker.speed,
        dir: 1,
      );
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
    for (final (i, spot) in _standSpots.indexed) {
      final c = _crowd[i];
      final img = c.img;
      if (img == null) continue;
      _drawSprite(
        canvas,
        img,
        c.frame,
        cx: w * (spot.$1 + c.xJit),
        footY: h * spot.$2,
        height: spot.$3 * c.hMul,
        flip: c.flip,
        tint: c.tint,
      );
    }

    if (_walker.img == null) return;
    // Bước chân theo quãng đường thực: ~30px một frame, hết trượt băng.
    final stride = (30.0 * _walkDist * w).floor();
    final runIdx = (stride % 4) + 1;
    _drawSprite(
      canvas,
      _walker.img!,
      'run$runIdx',
      cx: w * _walkerX,
      footY: h * 0.99,
      height: 252,
      flip: _walker.dir < 0,
      tint: _walker.tint,
    );
  }

  void _drawSprite(
    Canvas canvas,
    ui.Image atlas,
    String slot, {
    required double cx,
    required double footY,
    required double height,
    required bool flip,
    Color? tint,
  }) {
    final idx = AlleyGame.slots.indexOf(slot);
    if (idx < 0) return;
    final cell = atlas.width / 4;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.save();
    canvas.translate(cx, footY);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      atlas,
      Rect.fromLTWH((idx % 4) * cell, (idx ~/ 4) * cell, cell, cell),
      Rect.fromLTWH(-height / 2, -height, height, height),
      paint,
    );
    canvas.restore();
  }
}
