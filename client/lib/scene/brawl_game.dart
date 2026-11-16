import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paint_utils.dart';
import 'scene_image.dart';

/// Atlas 1024×1024: lưới 4×4, mỗi ô 256×256, xếp đúng thứ tự [slots].
/// Thiếu ảnh → trả null và trận đánh rơi về hình vẽ tay cũ.
class FightFrames {
  FightFrames(this.image);

  final ui.Image image;

  int? indexOf(String slot) {
    final i = slots.indexOf(slot);
    return i < 0 ? null : i;
  }

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
      return FightFrames(await loadFightFrame('atlas_$prefix'));
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

  /// Các bộ đàn em (atlas_m1…m8) để đám đông mỗi đứa một kiểu.
  final List<FightFrames> variants = [];

  FightFrames? minionFrames(int i, {required bool mine}) {
    if (variants.isEmpty) return null;
    // Hai bên lệch hệ số để cùng index không ra cùng một bộ.
    final n = variants.length;
    return variants[(mine ? i * 3 + 1 : i * 5 + 4) % n];
  }

  bool get myGun => myWeapon.contains('Súng') || myWeapon.contains('Hàng nóng');

  @override
  Color backgroundColor() => const Color(0xFF07080C);

  @override
  Future<void> onLoad() async {
    bg = await loadSceneImage('bg_brawl');
    final sets = await Future.wait([
      FightFrames.load('p'),
      FightFrames.load('e'),
      for (final v in const ['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8'])
        FightFrames.load(v),
    ]);
    myFrames = sets[0];
    enemyFrames = sets[1];
    variants.addAll(sets.skip(2).whereType<FightFrames>());
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

/// Giọt máu bắn ra khi trúng đòn, có trọng lực và đọng lại thành vũng.
class _Drop {
  _Drop(this.x, this.y, this.vx, this.vy, this.size, this.color);

  double x;
  double y;
  double vx;
  double vy;
  final double size;
  final Color color;
  double age = 0;
  static const life = 0.9;
}

/// Vũng máu trên nền, mờ dần rồi biến mất.
class _Splat {
  _Splat(this.x, this.y, this.r, this.color);

  final double x;
  final double y;
  final double r;
  final Color color;
  double age = 0;
  static const life = 4.0;
}

/// Chớp lửa đầu nòng khi bắn.
class _Muzzle {
  _Muzzle(this.x, this.y);

  final double x;
  final double y;
  double age = 0;
  static const life = 0.09;
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
  _DrawItem(
    this.frames,
    this.slot,
    this.cx,
    this.cy,
    this.height,
    this.flip,
    this.flash, [
    this.tint = const Color(0xFFFFFFFF),
  ]);

  final FightFrames frames;
  final String slot;
  final double cx;
  final double cy;
  final double height;
  final bool flip;
  final double flash;

  /// Màu áo: nhân với sprite để mỗi đứa một tông.
  final Color tint;
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
  double _nextFx = 0;
  final math.Random _rnd = math.Random();
  final List<_Drop> _blood = [];
  final List<_Splat> _splats = [];
  final List<_Muzzle> _muzzles = [];
  static const _bloodColors = [
    Color(0xFFB00018),
    Color(0xFF8A0012),
    Color(0xFFD91E2B),
  ];
  double _hitStop = 0;
  double _knockMe = 0;
  double _knockEn = 0;

  /// Tông áo từng nhân vật: rất nhạt để không phá màu sprite gốc.
  static const _tints = [
    Color(0xFFFFFFFF),
    Color(0xFFFFE0D2),
    Color(0xFFD8E6FF),
    Color(0xFFE2FFD8),
    Color(0xFFFFF0C0),
    Color(0xFFEEDCFF),
  ];

  Color _tintFor(String name) {
    var h = 7;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _tints[h % _tints.length];
  }

  Color _tintOf(int i, {required bool mine}) => _tints[
      (_noise(mine ? i : i + 31, 13) * _tints.length).floor() % _tints.length];

  /// Số người mỗi bên trong cảnh hỗn chiến (1 đại ca + 15 đàn em).
  static const _crowd = 16;

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
    // Rải đòn so le trong ~12s: có nhịp dồn dập, có quãng nghỉ, xen đòn đệm
    // (không mất máu) để trận nào cũng xem được 10-15s chém nhau.
    const intro = 2000.0;
    const span = 12000.0;
    final total = math.max(evs.length, 8);
    final rnd = math.Random(evs.length * 7919 + _maxMyHp + game.myCount * 131);
    final weights = List<double>.generate(total, (_) => 0.45 + rnd.nextDouble());
    final weightSum = weights.fold<double>(0, (a, b) => a + b);
    final times = <double>[];
    var cursor = intro;
    for (final w in weights) {
      times.add(cursor);
      cursor += span * w / weightSum;
    }
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
      final at = times[b];
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
          _REv(
            at,
            rnd.nextBool(),
            false,
            0,
            lastHpMe,
            lastHpEn,
            false,
            real: false,
          ),
        );
      }
    }

    const approach = 500.0;
    const strike = 320.0;
    final firstRAt = _rEvs.isEmpty ? 2600.0 : _rEvs.first.rAt;
    // Hai băng chạy vào từ ngoài màn hình một lần rồi lao ra đánh.
    _segs.add(_Seg(true, 'run', 0, firstRAt - approach, -0.55, 0.20));
    _segs.add(_Seg(false, 'run', 0, firstRAt - approach, -0.55, 0.20));
    for (final e in _rEvs) {
      final home = e.mine && game.myGun ? 0.12 : 0.20;
      _segs.add(_Seg(e.mine, 'atk', e.rAt, e.rAt + strike, home, home + 0.11));
      if (e.real) {
        final defHome = !e.mine && game.myGun ? 0.12 : 0.20;
        _segs.add(
          _Seg(!e.mine, 'hurt', e.rAt, e.rAt + 300, defHome, defHome - 0.07),
        );
      }
    }
    _endAt = (_rEvs.isEmpty ? 14000.0 : _rEvs.last.rAt) + 2200;
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
    // Hit-stop: khựng một nhịp khi trúng đòn nặng cho đã tay.
    if (_hitStop > 0) {
      _hitStop = math.max(0, _hitStop - dt);
      dt *= 0.18;
    }
    _t += dt;
    _elapsed += dt * 1000;
    _knockMe = math.max(0, _knockMe - dt * 6);
    _knockEn = math.max(0, _knockEn - dt * 6);
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

    final groundY = size.y * 0.78;
    for (final d in _blood) {
      d.age += dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.vy += 1100 * dt;
    }
    _blood.removeWhere((d) {
      if (d.age >= _Drop.life) return true;
      if (size.y > 0 && d.y >= groundY) {
        if (_splats.length >= 40) _splats.removeAt(0);
        _splats.add(
          _Splat(d.x, groundY, 3 + d.size, d.color.withValues(alpha: 0.5)),
        );
        return true;
      }
      return false;
    });
    for (final s in _splats) {
      s.age += dt;
    }
    _splats.removeWhere((s) => s.age >= _Splat.life);
    for (final m in _muzzles) {
      m.age += dt;
    }
    _muzzles.removeWhere((m) => m.age >= _Muzzle.life);

    _ghostMe = math.max(
      _hpMe.toDouble(),
      _ghostMe - _maxMyHp * dt * (0.45 + (_maxMyHp - _hpMe) / _maxMyHp * 0.6),
    );
    _ghostEn = math.max(
      _hpEn.toDouble(),
      _ghostEn -
          _maxEnemyHp * dt * (0.45 + (_maxEnemyHp - _hpEn) / _maxEnemyHp * 0.6),
    );

    // Va chạm lẻ tẻ trong đám đông để cảnh lúc nào cũng động.
    if (_koAt < 0 && size.x > 0 && _elapsed > _nextFx) {
      _nextFx = _elapsed + 240 + _rnd.nextDouble() * 420;
      final x = size.x * (0.06 + _rnd.nextDouble() * 0.88);
      final y = size.y * (0.52 + _rnd.nextDouble() * 0.24);
      final color = [Colors.white, GH.red, GH.cyan][_rnd.nextInt(3)];
      _spawnSparks(x, y, color.withValues(alpha: 0.7), count: 3);
      if (_rnd.nextBool()) {
        _arcs.add(_Arc(x, y, _rnd.nextBool(), color.withValues(alpha: 0.3)));
      }
    }

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
      if (e.miss) {
        if (e.mine) {
          _lungeMe = 1;
        } else {
          _lungeEn = 1;
        }
        _shake = 0.4;
        _popups.add(
          _Popup(e.mine ? enemyX : myX, size.y * 0.42, 'NÉ!', GH.cyan, _elapsed),
        );
      } else if (e.mine) {
        _lungeMe = 1;
        _shake = e.crit ? 1.6 : 1.0;
        _crowdFlash = 1;
        _comboMe = (_lastHitSide == 'me' && _elapsed - _lastHitAt < 1400)
            ? _comboMe + 1
            : 1;
        _comboEn = 0;
        _flashEn = 1;
        _spawnSparks(enemyX, size.y * 0.60, e.crit ? GH.gold : Colors.white);
        _spawnBlood(
          enemyX,
          size.y * 0.60,
          true,
          count: e.crit ? 18 : 10,
        );
        _knockEn = 1;
        if (e.crit) _hitStop = 0.06;
        if (game.myGun) {
          _muzzles.add(_Muzzle(size.x * 0.41, size.y * 0.64));
          _tracers.add(
            _Tracer(
              size.x * 0.41,
              size.y * 0.64,
              enemyX - size.x * 0.03,
              size.y * 0.65,
            ),
          );
          // Vỏ đạn văng ra.
          _blood.add(
            _Drop(
              size.x * 0.40,
              size.y * 0.62,
              -60 - _rnd.nextDouble() * 60,
              -120 - _rnd.nextDouble() * 80,
              2.5,
              const Color(0xFFD9A521),
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
          _arcs.add(
            _Arc(
              size.x * 0.50,
              size.y * 0.64,
              false,
              Colors.white.withValues(alpha: 0.7),
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
      } else {
        _lungeEn = 1;
        _shake = 1;
        _comboEn = (_lastHitSide == 'enemy' && _elapsed - _lastHitAt < 1400)
            ? _comboEn + 1
            : 1;
        _comboMe = 0;
        _flashMe = 1;
        _spawnSparks(myX, size.y * 0.60, GH.red);
        _spawnBlood(myX, size.y * 0.60, false, count: e.crit ? 16 : 9);
        _knockMe = 1;
        if (e.crit) _hitStop = 0.05;
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

  void _spawnBlood(double x, double y, bool toRight, {int count = 10}) {
    for (var i = 0; i < count; i++) {
      _blood.add(
        _Drop(
          x + (_rnd.nextDouble() - 0.5) * 16,
          y + (_rnd.nextDouble() - 0.5) * 28,
          (toRight ? 1 : -1) * (40 + _rnd.nextDouble() * 190),
          -110 - _rnd.nextDouble() * 190,
          2 + _rnd.nextDouble() * 3,
          _bloodColors[_rnd.nextInt(_bloodColors.length)],
        ),
      );
    }
    if (_splats.length >= 40) _splats.removeAt(0);
    _splats.add(
      _Splat(
        x,
        size.y * 0.78,
        8 + _rnd.nextDouble() * 12,
        _bloodColors[0].withValues(alpha: 0.55),
      ),
    );
  }

  void _spawnSparks(double x, double y, Color color, {int count = 10}) {
    for (var i = 0; i < count; i++) {
      final off = i - (count - 1) / 2;
      _sparks.add(
        _Spark(
          x + off * 4,
          y + (i % 3 - 1) * 5,
          -math.pi / 2 + off * 0.42,
          color,
        ),
      );
    }
  }

  /// Nhiễu cố định theo từng lính: đội hình không xếp hàng ngay ngắn nhưng
  /// cũng không rung giật giữa các frame.
  double _noise(int i, int salt) {
    final h = (i * 73856093) ^ (salt * 19349663);
    return (h % 1000) / 1000.0;
  }

  /// Mỗi đàn em tự tìm điểm đánh lệch nhau, rồi lao ra – lùi vào theo nhịp
  /// riêng, nên cảnh trông như hỗn chiến chứ không phải dàn hàng.
  ({double cx, double cy, double hh, String state, double cyc}) _minionPose(
    int i, {
    required bool mine,
  }) {
    const introEnd = 2000.0;
    final idx = i - 1;
    // 15 đàn em: 5 hàng × 3 cột, 2 hàng sau lùi sâu cho cảnh đầy hơn.
    const rows = 5;
    final row = idx % rows;
    final col = idx ~/ rows;
    final depth = row / (rows - 1);
    final hh = 0.24 + 0.10 * depth;
    final cy = 0.57 + 0.30 * depth + (_noise(i, 1) - 0.5) * 0.02;
    final home = mine ? 0.02 + col * 0.10 : 0.98 - col * 0.10;
    final pairX = 0.12 + col * 0.33 + (_noise(i, 2) - 0.5) * 0.10;
    final gap = 0.03 + _noise(i, 3) * 0.05;
    final spot = mine ? pairX - gap : pairX + gap;

    if (_elapsed < introEnd) {
      final delay = _noise(i, 4) * 600;
      final k = ((_elapsed - delay) / (introEnd - delay)).clamp(0.0, 1.0);
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
      if (iWin) return (cx: spot, cy: cy, hh: hh, state: 'win', cyc: 0);
      // Bên thua quay đầu chạy ngược về chỗ xuất phát.
      final flee = ((_elapsed - _koAt) / 1400).clamp(0.0, 1.0);
      return (
        cx: spot + (mine ? -1 : 1) * flee * 1.2,
        cy: cy,
        hh: hh,
        state: 'flee',
        cyc: 0,
      );
    }

    final chargeAt = introEnd + _noise(i, 5) * 700;
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

    final period = 1100.0 + _noise(i, 6) * 1500.0;
    final cyc =
        (((_elapsed - introEnd + _noise(i, 7) * period) % period) / period);
    final swing = math.sin(math.pi * (cyc / 0.55).clamp(0.0, 1.0));
    final cx = spot + (mine ? 1 : -1) * swing * (0.012 + _noise(i, 8) * 0.03);
    final String state;
    if (cyc < 0.42) {
      state = 'atk';
    } else if (cyc < 0.52 && _noise(i, 9) > 0.5) {
      state = 'hurt';
    } else {
      state = 'idle';
    }
    return (cx: cx, cy: cy, hh: hh, state: state, cyc: cyc);
  }

  String _minionFrame(String state, double cyc, int i) {
    switch (state) {
      case 'run':
        return 'run${(((_elapsed / 110) + i * 2) % 4).floor() + 1}';
      case 'atk':
        return cyc < 0.22 ? 'atk1' : 'atk2';
      case 'hurt':
        return 'hurt';
      case 'flee':
        return 'run${(((_elapsed / 70) + i * 2) % 4).floor() + 1}';
      case 'win':
        return 'win';
      default:
        return 'idle${(((_elapsed / 450) + i) % 2).floor() + 1}';
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
    final home = mine && game.myGun ? 0.12 : 0.20;
    // Nhấp nhô nhẹ khi đứng để nhân vật không đứng im như tượng.
    var dash = home + math.sin(_elapsed / 620 + (mine ? 0.0 : math.pi)) * 0.006;
    var t = 0.0;
    if (best != null) {
      t = ((_elapsed - best.start) / (best.end - best.start)).clamp(0.0, 1.0);
      // Ra đòn/ăn đòn theo nhịp sin: lao tới rồi rút về, không giật cục.
      final k = best.kind == 'run' ? t * t * (3 - 2 * t) : math.sin(math.pi * t);
      dash = best.dashFrom + (best.dashTo - best.dashFrom) * k;
      state = best.kind;
    }
    if (_koTime > 0) {
      final loser = _koSide == (mine ? 'me' : 'enemy');
      if (loser) {
        // Chạy ngược ra khỏi màn về hướng xuất phát.
        final flee = ((_elapsed - _koAt) / 1400).clamp(0.0, 1.0);
        return _Pose('flee', home - 0.75 * flee, flee);
      }
      return _Pose('win', dash * (1 - _koTime), t);
    }
    return _Pose(state, dash, t);
  }

  String _frameFor(
    _Pose pose, {
    required bool gun,
    required double koTime,
    double phase = 0,
  }) {
    switch (pose.state) {
      case 'run':
        return 'run${(((_elapsed + phase * 400) / 90) % 4).floor() + 1}';
      case 'atk':
        if (gun) return pose.t < 0.45 ? 'aim' : 'fire';
        return pose.t < 0.45 ? 'atk1' : 'atk2';
      case 'hurt':
        return 'hurt';
      case 'ko':
        return koTime < 0.5 ? 'ko1' : 'ko2';
      case 'flee':
        return 'run${(((_elapsed + phase * 400) / 70) % 4).floor() + 1}';
      case 'win':
        return 'win';
      default:
        final idleIdx = (((_elapsed + phase * 500) / 450) % 2).floor() + 1;
        return gun ? 'gun$idleIdx' : 'idle$idleIdx';
    }
  }

  void _drawFrame(
    Canvas canvas,
    FightFrames frames,
    String slot, {
    required double cx,
    required double groundY,
    required double height,
    required bool flip,
    double flash = 0,
    Color tint = const Color(0xFFFFFFFF),
  }) {
    final idx = frames.indexOf(slot);
    if (idx == null) return;
    final cell = frames.image.width / 4;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (flash > 0) {
      paint.colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: (flash * 0.8).clamp(0.0, 1.0)),
        BlendMode.srcATop,
      );
    } else if (tint != const Color(0xFFFFFFFF)) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.save();
    canvas.translate(cx, groundY);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      frames.image,
      Rect.fromLTWH((idx % 4) * cell, (idx ~/ 4) * cell, cell, cell),
      Rect.fromLTWH(-height / 2, -height, height, height),
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
    // Camera punch nhẹ mỗi cú va chạm.
    final punch = 1 + 0.02 * _shake;
    canvas.translate(w / 2, h / 2);
    canvas.scale(punch);
    canvas.translate(-w / 2, -h / 2);

    _background(canvas, w, h);
    final ground = h * 0.78;

    // Vũng máu nằm dưới chân nhân vật.
    for (final s in _splats) {
      final a = (1 - s.age / _Splat.life).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s.x, s.y),
          width: s.r * 2.4,
          height: s.r * 0.9,
        ),
        Paint()..color = s.color.withValues(alpha: s.color.a * a),
      );
    }

    final koTime = _koAt < 0 ? 0.0 : ((_elapsed - _koAt) / 500).clamp(0.0, 1.0);

    final queue = <_DrawItem>[];

    for (var i = _crowd - 1; i >= 0; i--) {
      final isLeader = i == 0;
      final falling = isLeader && _koSide == 'enemy' ? koTime : 0.0;
      if (game.enemyFrames != null) {
        // Lính: bộ biến thể riêng; thiếu thì trộn 2 bộ gốc.
        final frames = isLeader
            ? game.enemyFrames!
            : game.minionFrames(i, mine: false) ??
                (_noise(i, 19) > 0.5
                    ? game.enemyFrames!
                    : game.myFrames ?? game.enemyFrames!);
        String slot;
        double cx;
        double cy = ground;
        double height;
        var flip = true;
        if (isLeader) {
          final pose = _pose(mine: false);
          slot = _frameFor(pose, gun: false, koTime: koTime);
          cx = w * (0.74 - pose.dash) + _knockEn * w * 0.03;
          height = h * 0.36;
          // Bỏ chạy thì quay mặt về hướng chạy.
          flip = pose.state != 'flee';
        } else {
          final mp = _minionPose(i, mine: false);
          slot = _minionFrame(mp.state, mp.cyc, i);
          cx = w * mp.cx;
          cy = h * mp.cy;
          height = h * mp.hh * (0.94 + _noise(i, 12) * 0.12);
          flip = mp.state != 'flee';
        }
        queue.add(
          _DrawItem(
            frames,
            slot,
            cx,
            cy,
            height,
            flip,
            _flashEn,
            isLeader ? _tintFor(game.enemyName) : _tintOf(i, mine: false),
          ),
        );
        continue;
      }
      _fighter(
        canvas,
        Offset(w * 0.74 + i * w * 0.05, ground),
        h * (isLeader ? 0.42 : 0.30),
        isLeader
            ? GH.red
            : Color.lerp(GH.red, _tintOf(i, mine: false), 0.45)!,
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
      final falling = isLeader && _koSide == 'me' ? koTime : 0.0;
      if (game.myFrames != null) {
        final frames = isLeader
            ? game.myFrames!
            : game.minionFrames(i, mine: true) ??
                (_noise(i, 11) > 0.5
                    ? game.myFrames!
                    : game.enemyFrames ?? game.myFrames!);
        String slot;
        double cx;
        double cy = ground;
        double height;
        var flip = false;
        if (isLeader) {
          final pose = _pose(mine: true);
          slot = _frameFor(pose, gun: game.myGun, koTime: koTime);
          cx = w * (0.26 + pose.dash) - _knockMe * w * 0.03;
          height = h * 0.36;
          flip = pose.state == 'flee';
        } else {
          final mp = _minionPose(i, mine: true);
          slot = _minionFrame(mp.state, mp.cyc, i);
          cx = w * mp.cx;
          cy = h * mp.cy;
          height = h * mp.hh * (0.94 + _noise(i, 12) * 0.12);
          flip = mp.state == 'flee';
        }
        queue.add(
          _DrawItem(
            frames,
            slot,
            cx,
            cy,
            height,
            flip,
            _flashMe,
            isLeader ? _tintFor(game.myName) : _tintOf(i, mine: true),
          ),
        );
        continue;
      }
      _fighter(
        canvas,
        Offset(w * 0.26 - i * w * 0.05, ground),
        h * (isLeader ? 0.42 : 0.30),
        isLeader
            ? GH.cyan
            : Color.lerp(GH.cyan, _tintOf(i, mine: true), 0.45)!,
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
        d.frames,
        d.slot,
        cx: d.cx,
        groundY: d.cy,
        height: d.height,
        flip: d.flip,
        flash: d.flash,
        tint: d.tint,
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
        // Quầng mờ + lưỡi chém + lõi trắng cho ra dáng đường chém.
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * (1 - k) + 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = arc.color.withValues(alpha: 0.35 * (1 - k)),
      );
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
      canvas.drawArc(
        rect,
        start,
        math.pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.85 * (1 - k)),
      );
    }

    for (final d in _blood) {
      final a = (1 - d.age / _Drop.life).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.size,
        Paint()..color = d.color.withValues(alpha: a),
      );
    }

    for (final m in _muzzles) {
      final k = (m.age / _Muzzle.life).clamp(0.0, 1.0);
      final r = 12 + 20 * k;
      final center = Offset(m.x, m.y);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF3B0).withValues(alpha: 1 - k),
              const Color(0x00FFF3B0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
      for (var i = 0; i < 3; i++) {
        final ang = -0.5 + i * 0.5;
        canvas.drawLine(
          center,
          center +
              Offset(math.cos(ang) * r * 1.7, math.sin(ang) * r * 1.7),
          Paint()
            ..color = const Color(0xFFFFE080).withValues(alpha: 1 - k)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
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
