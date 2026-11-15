import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paint_utils.dart';
import 'scene_image.dart';

/// Bộ 16 frame cắt từ sprite sheet PHASE 2D (`assets/fight/`).
/// Thiếu ảnh bất kỳ → trả null và trận đánh rơi về hình vẽ tay cũ.
class FightFrames {
  FightFrames(this.map);

  final Map<String, ui.Image> map;
  ui.Image? operator [](String slot) => map[slot];

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

  static Future<FightFrames?> load(String prefix) async {
    try {
      final out = <String, ui.Image>{};
      for (final slot in slots) {
        out[slot] = await loadFightFrame('${prefix}_$slot');
      }
      return FightFrames(out);
    } catch (e) {
      assert(() {
        debugPrint('FightFrames.load($prefix) lỗi: $e');
        return true;
      }());
      return null;
    }
  }
}

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

  late final ui.Image bg;
  FightFrames? myFrames;
  FightFrames? enemyFrames;

  bool get myGun => myWeapon.contains('Súng') || myWeapon.contains('Hàng nóng');

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    bg = await loadSceneImage('bg_brawl');
    myFrames = await FightFrames.load('p');
    enemyFrames = await FightFrames.load('e');
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
  static const life = 0.45;
}

/// Vòng chém cung tròn tại điểm ra đòn.
class _Arc {
  _Arc(this.x, this.y, this.flip, this.color);

  final double x;
  final double y;
  final bool flip;
  final Color color;
  double age = 0;
  static const life = 0.22;
}

class _Tracer {
  _Tracer(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  double age = 0;
  static const life = 0.14;
}

/// Một nhịp di chuyển của lính chính: chạy tới — ra đòn — chạy lui.
class _Seg {
  _Seg(this.mine, this.kind, this.start, this.end, this.dashFrom, this.dashTo);

  final bool mine;
  final String kind; // run | atk | hurt
  final double start;
  final double end;
  final double dashFrom;
  final double dashTo;
}

/// Sự kiện đòn đã quy đổi sang thời gian thực của trận (ms).
class _REv {
  _REv(
    this.rAt,
    this.mine,
    this.crit,
    this.dmg,
    this.myHp,
    this.enemyHp,
    this.miss, {
    this.real = true,
  });

  final double rAt;
  final bool mine;
  final bool crit;
  final int dmg;
  final int myHp;
  final int enemyHp;
  final bool miss;

  /// false = đòn đệm cho có nhịp, không trừ máu.
  final bool real;
}

class _Pose {
  const _Pose(this.state, this.dash, this.t);

  final String state; // idle | run | atk | hurt | ko | win
  final double dash;
  final double t; // 0..1 trong nhịp
}

/// Một nhân vật chờ vẽ, sắp theo trục y để bên gần camera nằm trên.
class _DrawItem {
  _DrawItem(this.img, this.cx, this.cy, this.height, this.flip, this.flash);

  final ui.Image img;
  final double cx;
  final double cy;
  final double height;
  final bool flip;
  final double flash;
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
  final List<_Tracer> _tracers = [];
  final List<_Arc> _arcs = [];
  final List<_Seg> _segs = [];
  final List<_REv> _rEvs = [];
  double _koTime = 0;
  double _flashMe = 0;
  double _flashEn = 0;
  double _endAt = 7000;

  /// Số người mỗi bên trong cảnh hỗn chiến (1 đại ca + đàn em).
  static const _crowd = 20;

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
    // Chia trận thành các nhịp đánh đều nhau trong ~12s; sự kiện thật của
    // server rải vào các nhịp, nhịp trống là đòn đệm (không mất máu) để trận
    // nào cũng xem được 10-15s chém nhau.
    const intro = 2000.0;
    const span = 12000.0;
    final total = math.max(evs.length, 8);
    final gap = span / total;
    final slotOf = List<int?>.filled(total, null);
    for (var i = 0; i < evs.length; i++) {
      // Đòn cuối (thường là đòn hạ gục) luôn rơi vào nhịp cuối.
      final slot = evs.length == 1
          ? total - 1
          : ((i * (total - 1)) / (evs.length - 1)).round();
      slotOf[slot] = i;
    }
    var lastHpMe = _maxMyHp;
    var lastHpEn = _maxEnemyHp;
    for (var b = 0; b < total; b++) {
      final at = intro + b * gap;
      final idx = slotOf[b];
      if (idx != null) {
        final e = evs[idx];
        lastHpMe = e.myHp;
        lastHpEn = e.enemyHp;
        _rEvs.add(
          _REv(at, e.side == 'me', e.crit, e.dmg, e.myHp, e.enemyHp, e.miss),
        );
      } else {
        _rEvs.add(
          _REv(at, b.isEven, false, 0, lastHpMe, lastHpEn, false, real: false),
        );
      }
    }

    const approach = 500.0;
    const strike = 320.0;
    final firstRAt = _rEvs.isEmpty ? 2600.0 : _rEvs.first.rAt;
    // Hai băng chạy vào từ ngoài màn hình một lần rồi đứng yên tại chỗ đánh.
    _segs.add(_Seg(true, 'run', 0, firstRAt - approach, -0.55, 0.20));
    _segs.add(_Seg(false, 'run', 0, firstRAt - approach, -0.55, 0.20));
    for (final e in _rEvs) {
      final dash = e.mine && game.myGun ? 0.12 : 0.20;
      _segs.add(_Seg(e.mine, 'atk', e.rAt, e.rAt + strike, dash, dash));
      if (e.real) {
        _segs.add(_Seg(!e.mine, 'hurt', e.rAt, e.rAt + 260, dash, dash));
      }
    }
    _endAt = (_rEvs.isEmpty ? 14000.0 : _rEvs.last.rAt) + 1600;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done &&
        _popups.isEmpty &&
        _sparks.isEmpty &&
        _arcs.isEmpty &&
        _tracers.isEmpty &&
        _elapsed > 0) {
      return;
    }
    _t += dt;
    _elapsed += dt * 1000;
    _shake = math.max(0, _shake - dt * 3.5);
    _lungeMe = math.max(0, _lungeMe - dt * 4);
    _lungeEn = math.max(0, _lungeEn - dt * 4);
    _crowdFlash = math.max(0, _crowdFlash - dt * 3);
    _koTime = _koAt < 0 ? 0 : ((_elapsed - _koAt) / 500).clamp(0.0, 1.0);
    _flashMe = math.max(0, _flashMe - dt * 5);
    _flashEn = math.max(0, _flashEn - dt * 5);
    for (final tr in _tracers) {
      tr.age += dt;
    }
    _tracers.removeWhere((tr) => tr.age >= _Tracer.life);
    for (final arc in _arcs) {
      arc.age += dt;
    }
    _arcs.removeWhere((arc) => arc.age >= _Arc.life);

    _ghostMe = math.max(
      _hpMe.toDouble(),
      _ghostMe - _maxMyHp * dt * (0.45 + (_maxMyHp - _hpMe) / _maxMyHp * 0.6),
    );
    _ghostEn = math.max(
      _hpEn.toDouble(),
      _ghostEn -
          _maxEnemyHp * dt * (0.45 + (_maxEnemyHp - _hpEn) / _maxEnemyHp * 0.6),
    );

    final evs = _rEvs;
    while (_applied < evs.length &&
        _koAt < 0 &&
        evs[_applied].rAt <= _elapsed) {
      final e = evs[_applied++];
      final enemyX = size.x * 0.56;
      final myX = size.x * 0.40;
      if (!e.real) {
        // Đòn đệm: có chạy tới và vung vũ khí, không trừ máu.
        if (e.mine) {
          _lungeMe = 1;
          _shake = math.max(_shake, 0.3);
          _spawnSparks(
            enemyX,
            size.y * 0.60,
            Colors.white.withValues(alpha: 0.5),
          );
          _arcs.add(
            _Arc(
              size.x * 0.50,
              size.y * 0.64,
              false,
              Colors.white.withValues(alpha: 0.45),
            ),
          );
        } else {
          _lungeEn = 1;
          _shake = math.max(_shake, 0.3);
          _spawnSparks(myX, size.y * 0.60, GH.red.withValues(alpha: 0.5));
          _arcs.add(
            _Arc(
              size.x * 0.44,
              size.y * 0.64,
              true,
              GH.red.withValues(alpha: 0.45),
            ),
          );
        }
        _lastHitSide = e.mine ? 'me' : 'enemy';
        _lastHitAt = _elapsed;
        continue;
      }
      _hpMe = e.myHp;
      _hpEn = e.enemyHp;
      if (e.mine) {
        _lungeMe = 1;
        _shake = e.crit ? 1.6 : 1.0;
        _crowdFlash = 1;
        _comboMe = (_lastHitSide == 'me' && _elapsed - _lastHitAt < 1400)
            ? _comboMe + 1
            : 1;
        _comboEn = 0;
        _flashEn = 1;
        _spawnSparks(enemyX, size.y * 0.60, e.crit ? GH.gold : Colors.white);
        if (game.myGun) {
          _tracers.add(
            _Tracer(
              size.x * 0.41,
              size.y * 0.64,
              enemyX - size.x * 0.03,
              size.y * 0.65,
            ),
          );
          _spawnSparks(size.x * 0.41, size.y * 0.64, GH.gold);
        } else {
          _arcs.add(
            _Arc(
              size.x * 0.50,
              size.y * 0.64,
              false,
              e.crit ? GH.gold : Colors.white,
            ),
          );
        }
        _popups.add(
          _Popup(
            enemyX,
            size.y * 0.42,
            e.crit ? 'CHÍ MẠNG -${e.dmg}' : '-${e.dmg}',
            e.crit ? GH.gold : Colors.white,
            _elapsed,
          ),
        );
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
        _flashMe = 1;
        _spawnSparks(myX, size.y * 0.60, GH.red);
        _arcs.add(_Arc(size.x * 0.44, size.y * 0.64, true, GH.red));
        _popups.add(_Popup(myX, size.y * 0.42, '-${e.dmg}', GH.red, _elapsed));
      }
      _lastHitSide = e.mine ? 'me' : 'enemy';
      _lastHitAt = _elapsed;
      if (_hpEn <= 0 || _hpMe <= 0) {
        _koSide = _hpEn <= 0 ? 'enemy' : 'me';
        _koAt = _elapsed;
      }
    }

    _popups.removeWhere((p) => _elapsed - p.spawnAt >= _Popup.life * 1000);
    for (final s in _sparks) {
      s.age += dt;
    }
    _sparks.removeWhere((s) => s.age >= _Spark.life);

    final stopAt = _koAt >= 0 ? math.min(_endAt, _koAt + 2800) : _endAt;
    if (!_done && _elapsed >= stopAt) {
      _done = true;
      game.onFinished();
    }
  }

  void _spawnSparks(double x, double y, Color color) {
    for (var i = 0; i < 10; i++) {
      _sparks.add(
        _Spark(
          x + (i - 4.5) * 4,
          y + (i % 3 - 1) * 5,
          -math.pi / 2 + (i - 4.5) * 0.42,
          color,
        ),
      );
    }
  }

  /// Mỗi đàn em có cặp đấu riêng: chạy ra điểm hẹn ở giữa màn MỘT lần,
  /// sau đó đứng yên tại chỗ chém nhau. Tất cả cùng cỡ, 4 hàng × 5 cột.
  ({double cx, double cy, double hh, String state, double cyc}) _minionPose(
    int i, {
    required bool mine,
  }) {
    const introEnd = 2000.0;
    const hh = 0.13;
    final idx = i - 1;
    final row = idx % 4;
    final col = idx ~/ 4;
    final cy = const [0.70, 0.765, 0.83, 0.895][row];
    final home = mine ? 0.02 + col * 0.10 : 0.98 - col * 0.10;
    // Cặp đấu rải đều khắp chiều ngang: 5 cột, hai bên đối mặt nhau.
    final pairX = 0.10 + col * 0.20;
    final spot = mine ? pairX - 0.055 : pairX + 0.055;

    if (_elapsed < introEnd) {
      final k = ((_elapsed - idx * 40.0) / (introEnd - idx * 40.0)).clamp(
        0.0,
        1.0,
      );
      final start = mine ? -0.10 - col * 0.05 : 1.10 + col * 0.05;
      return (
        cx: start + (home - start) * k,
        cy: cy,
        hh: hh,
        state: 'run',
        cyc: 0,
      );
    }
    if (_koTime > 0) {
      final iWin = mine == (_koSide == 'enemy');
      return (cx: spot, cy: cy, hh: hh, state: iWin ? 'win' : 'idle', cyc: 0);
    }

    final chargeAt = introEnd + idx * 60.0;
    if (_elapsed < chargeAt + 700) {
      final out = ((_elapsed - chargeAt) / 700).clamp(0.0, 1.0);
      final ease = out * out * (3 - 2 * out);
      return (
        cx: home + (spot - home) * ease,
        cy: cy,
        hh: hh,
        state: 'run',
        cyc: 0,
      );
    }

    final period = 2.2 + (idx % 5) * 0.25;
    final cyc = (((_elapsed / 1000 - 2.0) / period + idx * 0.17) % 1.0);
    return (
      cx: spot,
      cy: cy,
      hh: hh,
      state: cyc > 0.65 ? 'atk' : 'idle',
      cyc: cyc,
    );
  }

  ui.Image? _minionFrame(FightFrames f, String state, double cyc, int i) {
    switch (state) {
      case 'run':
        return f['run${(((_elapsed / 110) + i * 2) % 4).floor() + 1}'];
      case 'atk':
        return f[cyc < 0.85 ? 'atk1' : 'atk2'];
      case 'win':
        return f['win'];
      default:
        return f['idle${(((_elapsed / 450) + i) % 2).floor() + 1}'];
    }
  }

  _Pose _pose({required bool mine}) {
    _Seg? best;
    for (final s in _segs) {
      if (s.mine != mine) continue;
      if (_elapsed >= s.start && _elapsed < s.end) {
        if (best == null || s.start > best.start) best = s;
      }
    }
    var state = 'idle';
    var dash = mine && game.myGun ? 0.12 : 0.20;
    var t = 0.0;
    if (best != null) {
      t = ((_elapsed - best.start) / (best.end - best.start)).clamp(0.0, 1.0);
      dash = best.dashFrom + (best.dashTo - best.dashFrom) * t;
      state = best.kind;
    }
    if (_koTime > 0) {
      final loser = _koSide == (mine ? 'me' : 'enemy');
      return _Pose(loser ? 'ko' : 'win', dash * (1 - _koTime), t);
    }
    return _Pose(state, dash, t);
  }

  ui.Image? _frameFor(
    FightFrames frames,
    _Pose pose, {
    required bool gun,
    required double koTime,
    double phase = 0,
  }) {
    switch (pose.state) {
      case 'run':
        return frames['run${(((_elapsed + phase * 400) / 90) % 4).floor() + 1}'];
      case 'atk':
        if (gun) return pose.t < 0.45 ? frames['aim'] : frames['fire'];
        return pose.t < 0.45 ? frames['atk1'] : frames['atk2'];
      case 'hurt':
        return frames['hurt'];
      case 'ko':
        return koTime < 0.5 ? frames['ko1'] : frames['ko2'];
      case 'win':
        return frames['win'];
      default:
        final idleIdx = (((_elapsed + phase * 500) / 450) % 2).floor() + 1;
        return frames[gun ? 'gun$idleIdx' : 'idle$idleIdx'];
    }
  }

  void _drawFrame(
    Canvas canvas,
    ui.Image img, {
    required double cx,
    required double groundY,
    required double height,
    required bool flip,
    double flash = 0,
  }) {
    final dw = height * img.width / img.height;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (flash > 0) {
      paint.colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: (flash * 0.8).clamp(0.0, 1.0)),
        BlendMode.srcATop,
      );
    }
    canvas.save();
    canvas.translate(cx, groundY);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-dw / 2, -height, dw, height),
      paint,
    );
    canvas.restore();
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

    final queue = <_DrawItem>[];

    for (var i = _crowd - 1; i >= 0; i--) {
      final isLeader = i == 0;
      if (!isLeader && _koTime > 0 && _koSide == 'enemy') continue;
      final falling = isLeader && _koSide == 'enemy' ? koTime : 0.0;
      if (game.enemyFrames != null) {
        ui.Image? img;
        double cx;
        double cy = ground;
        double height;
        if (isLeader) {
          final pose = _pose(mine: false);
          img = _frameFor(game.enemyFrames!, pose, gun: false, koTime: koTime);
          cx = w * (0.74 - pose.dash);
          height = h * 0.13;
        } else {
          final mp = _minionPose(i, mine: false);
          img = _minionFrame(game.enemyFrames!, mp.state, mp.cyc, i);
          cx = w * mp.cx;
          cy = h * mp.cy;
          height = h * mp.hh;
        }
        if (img != null) {
          queue.add(_DrawItem(img, cx, cy, height, true, _flashEn));
          continue;
        }
      }
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

    for (var i = _crowd - 1; i >= 0; i--) {
      final isLeader = i == 0;
      if (!isLeader && _koTime > 0 && _koSide == 'me') continue;
      final falling = isLeader && _koSide == 'me' ? koTime : 0.0;
      if (game.myFrames != null) {
        ui.Image? img;
        double cx;
        double cy = ground;
        double height;
        if (isLeader) {
          final pose = _pose(mine: true);
          img = _frameFor(
            game.myFrames!,
            pose,
            gun: game.myGun,
            koTime: koTime,
          );
          cx = w * (0.26 + pose.dash);
          height = h * 0.13;
        } else {
          final mp = _minionPose(i, mine: true);
          img = _minionFrame(game.myFrames!, mp.state, mp.cyc, i);
          cx = w * mp.cx;
          cy = h * mp.cy;
          height = h * mp.hh;
        }
        if (img != null) {
          queue.add(_DrawItem(img, cx, cy, height, false, _flashMe));
          continue;
        }
      }
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

    // Vẽ theo trục y: ai gần camera (y lớn) nằm trên, không chồng lung tung.
    queue.sort((a, b) => a.cy.compareTo(b.cy));
    for (final d in queue) {
      _drawFrame(
        canvas,
        d.img,
        cx: d.cx,
        groundY: d.cy,
        height: d.height,
        flip: d.flip,
        flash: d.flash,
      );
    }

    for (final arc in _arcs) {
      final k = (arc.age / _Arc.life).clamp(0.0, 1.0);
      final r = 30 + 36 * k;
      final rect = Rect.fromCircle(center: Offset(arc.x, arc.y), radius: r);
      final start = arc.flip ? math.pi / 2 - 0.2 : -math.pi / 2 + 0.2;
      canvas.drawArc(
        rect,
        start,
        math.pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - k) + 2
          ..strokeCap = StrokeCap.round
          ..color = arc.color.withValues(alpha: 1 - k),
      );
    }

    for (final tr in _tracers) {
      final k = (tr.age / _Tracer.life).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(tr.x1, tr.y1),
        Offset(tr.x2, tr.y2),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * (1 - k))
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(tr.x1, tr.y1),
        Offset(tr.x2, tr.y2),
        Paint()
          ..color = GH.cyan.withValues(alpha: 0.4 * (1 - k))
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final s in _sparks) {
      final k = (s.age / _Spark.life).clamp(0.0, 1.0);
      final len = 16 * (1 - k);
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
    final img = game.bg;
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = math.max(w / iw, h / ih);
    final dw = iw * scale;
    final dh = ih * scale;
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );

    // Làm tối trên/dưới để thanh máu và chân võ sĩ vẫn tách khỏi nền.
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.34),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC07080C), Color(0x0007080C)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.34)),
    );
    c.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0007080C), Color(0xE607080C)],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38)),
    );

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

  void _hpBar(
    Canvas c,
    Rect rect,
    double frac,
    double ghost,
    Color color,
    String name,
    String hp, {
    bool right = false,
  }) {
    paintRoundedRect(
      c,
      rect,
      const Color(0xFF141721),
      radius: 7,
      border: GH.line,
    );
    final g = ghost.clamp(0.0, 1.0);
    if (g > 0.01) {
      paintRoundedRect(
        c,
        Rect.fromLTWH(
          rect.left + 2,
          rect.top + 2,
          (rect.width - 4) * g,
          rect.height - 4,
        ),
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
        center: const Offset(0, 2),
        width: s * 0.9,
        height: s * 0.14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final leg = Paint()..color = const Color(0xFF111319);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * 0.26, -s * 0.52, s * 0.19, s * 0.52),
        Radius.circular(s * 0.06),
      ),
      leg,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.06, -s * 0.52, s * 0.19, s * 0.52),
        Radius.circular(s * 0.06),
      ),
      leg,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(-s * 0.34, -s * 1.22, s * 0.68, s * 0.74),
      Radius.circular(s * 0.17),
    );
    if (backlight) {
      paintGlowCircle(
        c,
        Offset(0, -s * 0.8),
        s * 0.55,
        accent.withValues(alpha: 0.07),
        blur: 18,
      );
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
        Radius.circular(s * 0.08),
      ),
      arm,
    );
    if (victory) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.34, -s * 1.72, s * 0.15, s * 0.6),
          Radius.circular(s * 0.08),
        ),
        arm,
      );
      c.drawCircle(
        Offset(s * 0.41, -s * 1.75),
        s * 0.09,
        Paint()..color = const Color(0xFFC98A63),
      );
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.42, -s * 1.14, s * 0.16, s * 0.58),
          Radius.circular(s * 0.08),
        ),
        arm,
      );
    }

    c.drawCircle(
      Offset(0, -s * 1.42),
      s * 0.24,
      Paint()..color = const Color(0xFFC98A63),
    );
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
      c.drawRect(Rect.fromLTWH(s * 0.46, -s * 0.9, s * 0.24, s * 0.08), gun);
      c.drawRect(Rect.fromLTWH(s * 0.46, -s * 0.9, s * 0.07, s * 0.16), gun);
    } else {
      final blade = Path()
        ..moveTo(s * 0.46, -s * 0.86)
        ..lineTo(s * 0.68, -s * 1.02)
        ..lineTo(s * 0.72, -s * 0.97)
        ..lineTo(s * 0.5, -s * 0.8)
        ..close();
      c.drawPath(blade, Paint()..color = const Color(0xFFB8C0CF));
      c.drawRect(
        Rect.fromLTWH(s * 0.44, -s * 0.9, s * 0.05, s * 0.12),
        Paint()..color = const Color(0xFF3A2A20),
      );
    }

    c.restore();
  }
}
