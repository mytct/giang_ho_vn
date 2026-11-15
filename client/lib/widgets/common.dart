import 'package:flutter/material.dart';

import '../theme.dart';

Color _bevelLight(Color c) => Color.lerp(c, Colors.white, 0.35)!;
Color _bevelDark(Color c) => Color.lerp(c, Colors.black, 0.45)!;

/// Flat, chunky pixel panel: hard black outline, 2px bevel, no blur.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = GH.panel,
    this.borderColor = GH.line,
    this.radius = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius > 0 ? 2 : 0);
    return Container(
      decoration: BoxDecoration(
        color: GH.ink,
        borderRadius: br,
        boxShadow: const [
          BoxShadow(
              color: Color(0xCC000000), offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: br,
          border: Border(
            top: BorderSide(color: _bevelLight(borderColor), width: 2),
            left: BorderSide(color: _bevelLight(borderColor), width: 2),
            right: BorderSide(color: _bevelDark(borderColor), width: 2),
            bottom: BorderSide(color: _bevelDark(borderColor), width: 2),
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = GH.cyan,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: GH.pixelFont,
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle(size: 9.5),
          ),
        ),
      ],
    );
  }
}

/// Pixel button: hard outline, bevel, offset shadow that collapses on press.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.color = GH.pink,
    this.icon,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final Color color;
  final IconData? icon;
  final double height;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  Color get _onColor =>
      widget.color.computeLuminance() > 0.55 ? GH.ink : Colors.white;

  void _setDown(bool value) {
    if (!widget.enabled) return;
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final onColor = _onColor;
    final icon = widget.icon;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.enabled ? widget.onTap : null,
        child: Transform.translate(
          offset: Offset(_down ? 3 : 0, _down ? 3 : 0),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: GH.ink,
              boxShadow: widget.enabled && !_down
                  ? const [
                      BoxShadow(
                          color: Color(0xCC000000),
                          offset: Offset(4, 4),
                          blurRadius: 0),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c,
                border: Border(
                  top: BorderSide(color: _bevelLight(c), width: 2),
                  left: BorderSide(color: _bevelLight(c), width: 2),
                  right: BorderSide(color: _bevelDark(c), width: 2),
                  bottom: BorderSide(color: _bevelDark(c), width: 2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: onColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GH.pixelFont,
                        color: onColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: GH.pink),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: const TextStyle(
                  fontFamily: GH.pixelFont,
                  color: GH.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Subtle pixel grid drawn behind content; pure paint, no assets.
class PixelGrid extends StatelessWidget {
  const PixelGrid({super.key, this.cell = 24});

  final double cell;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PixelGridPainter(cell: cell),
        size: Size.infinite,
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  const _PixelGridPainter({required this.cell});

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelGridPainter oldDelegate) =>
      oldDelegate.cell != cell;
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message,
          style: TextStyle(
              fontFamily: GH.pixelFont,
              color: error ? GH.red : GH.text,
              fontWeight: FontWeight.w700)),
      backgroundColor: error ? const Color(0xFF2A1118) : GH.panel2,
      duration: const Duration(milliseconds: 1800),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: GH.ink, width: 2),
      ),
    ));
}
