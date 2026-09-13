import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/music/chord_shape_catalog.dart';

class GuitarChordDiagram extends StatelessWidget {
  const GuitarChordDiagram({
    super.key,
    required this.shape,
    required this.notes,
    required this.color,
    required this.textColor,
    required this.lineColor,
    this.compact = false,
  });
  final GuitarChordShape? shape;
  final List<String> notes;
  final Color color, textColor, lineColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (shape == null) {
      return Text(
        notes.isEmpty
            ? 'Digitação não cadastrada.'
            : 'Notas: ${notes.join(' - ')}. Digitação não cadastrada.',
        style: TextStyle(color: textColor),
      );
    }
    return Semantics(
      label:
          '${shape!.label}: cordas E A D G B e; ${shape!.positions.join(', ')}',
      child: SizedBox(
        height: compact ? 208 : 244,
        width: double.infinity,
        child: CustomPaint(
          painter: GuitarChordPainter(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            shape: shape!,
            color: color,
            textColor: textColor,
            lineColor: lineColor,
          ),
        ),
      ),
    );
  }
}

class GuitarChordPainter extends CustomPainter {
  const GuitarChordPainter({
    this.fontFamily,
    required this.shape,
    required this.color,
    required this.textColor,
    required this.lineColor,
  });
  final GuitarChordShape shape;
  final String? fontFamily;
  final Color color, textColor, lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 80) return;
    final high = shape.baseFret > 1;
    final gutter = high ? 58.0 : 20.0;
    // All strings, markers and labels share one grid coordinate system.
    final gap = math
        .min((size.width - gutter - 20) / 5, (size.height - 58) / 5)
        .clamp(0.0, 34.0);
    final left = gutter + (size.width - gutter - 20 - gap * 5) / 2;
    const top = 28.0;
    final right = left + gap * 5;
    final bottom = top + gap * 5;
    final grid = Paint()
      ..color = Color.alphaBlend(textColor.withValues(alpha: .3), lineColor)
      ..strokeWidth = 1.3;
    final marker = Paint()..color = color;
    final radius = gap * .29;
    double x(int string) => left + gap * string;
    double y(int fret) => top + gap * (fret - shape.baseFret + .5);
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset(x(i), top), Offset(x(i), bottom), grid);
      canvas.drawLine(
        Offset(left, top + gap * i),
        Offset(right, top + gap * i),
        grid,
      );
    }
    if (!high) {
      canvas.drawLine(
        Offset(left, top),
        Offset(right, top),
        Paint()
          ..color = textColor
          ..strokeWidth = 4,
      );
    }
    if (high) {
      _text(
        canvas,
        '${shape.baseFret}ª casa',
        Offset(left - 33, top + gap / 2),
        textColor,
        11,
      );
    }
    for (final barre in shape.barres) {
      if (barre.fret < shape.baseFret || barre.fret >= shape.baseFret + 5) {
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x(barre.fromString) - radius,
            y(barre.fret) - radius,
            x(barre.endString) + radius,
            y(barre.fret) + radius,
          ),
          Radius.circular(radius),
        ),
        marker,
      );
    }
    const names = ['E', 'A', 'D', 'G', 'B', 'e'];
    for (var i = 0; i < 6; i++) {
      _text(canvas, names[i], Offset(x(i), bottom + 17), textColor, 11);
      final value = shape.positions[i];
      if (value == '0' || value == 'x') {
        _text(
          canvas,
          value == '0' ? 'o' : 'x',
          Offset(x(i), top - 15),
          textColor,
          13,
        );
        continue;
      }
      final fret = int.tryParse(value);
      if (fret == null || fret < shape.baseFret || fret >= shape.baseFret + 5) {
        continue;
      }
      final covered = shape.barres.any(
        (b) => b.fret == fret && i >= b.fromString && i <= b.endString,
      );
      if (!covered) canvas.drawCircle(Offset(x(i), y(fret)), radius, marker);
      final finger = shape.fingers == null ? null : shape.fingers![i];
      // A barre gets a single finger label at its first string.
      if (finger != null &&
          finger > 0 &&
          (!covered ||
              shape.barres.any((b) => b.fret == fret && b.fromString == i))) {
        _text(
          canvas,
          '$finger',
          Offset(x(i), y(fret)),
          Colors.black,
          math.min(12, radius * 1.45),
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  @override
  bool shouldRepaint(covariant GuitarChordPainter oldDelegate) =>
      oldDelegate.fontFamily != fontFamily ||
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor ||
      oldDelegate.lineColor != lineColor;
}
