import 'package:flutter/material.dart';

void paintText(
  Canvas c,
  String text,
  Offset at, {
  double size = 12,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w600,
  TextAlign align = TextAlign.left,
  double maxWidth = double.infinity,
  Color? glow,
  double glowBlur = 8,
}) {
  final style = TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: 1.15,
    fontFamily: 'Roboto',
  );
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  var dx = at.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;

  if (glow != null) {
    final gp = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          shadows: [
            Shadow(color: glow, blurRadius: glowBlur),
            Shadow(color: glow, blurRadius: glowBlur * 0.5),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    var gx = at.dx;
    if (align == TextAlign.center) gx -= gp.width / 2;
    if (align == TextAlign.right) gx -= gp.width;
    gp.paint(c, Offset(gx, at.dy));
  }
  tp.paint(c, Offset(dx, at.dy));
}

void paintRoundedRect(
  Canvas c,
  Rect rect,
  Color color, {
  double radius = 8,
  Color? border,
  double borderWidth = 1,
}) {
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  c.drawRRect(rr, Paint()..color = color);
  if (border != null) {
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = border,
    );
  }
}

void paintGlowCircle(
  Canvas c,
  Offset center,
  double radius,
  Color color, {
  double blur = 12,
}) {
  c.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}
