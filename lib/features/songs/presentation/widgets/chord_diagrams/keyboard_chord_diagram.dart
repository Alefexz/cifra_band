import 'dart:math' as math;
import 'package:flutter/material.dart';

class KeyboardChordDiagram extends StatelessWidget {
  const KeyboardChordDiagram({
    super.key,
    required this.notes,
    required this.color,
    required this.textColor,
    required this.lineColor,
    this.compact = false,
  });
  final List<String> notes;
  final Color color, textColor, lineColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Text(
        'Notas ainda não identificadas.',
        style: TextStyle(color: textColor),
      );
    }
    return Semantics(
      label: 'Teclado: ${notes.join(', ')}',
      child: SizedBox(
        height: compact ? 104 : 132,
        width: double.infinity,
        child: CustomPaint(
          painter: KeyboardChordPainter(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            notes: notes,
            color: color,
            lineColor: lineColor,
          ),
        ),
      ),
    );
  }
}

class KeyboardChordPainter extends CustomPainter {
  const KeyboardChordPainter({
    this.fontFamily,
    required this.notes,
    required this.color,
    required this.lineColor,
  });
  final List<String> notes;
  final String? fontFamily;
  final Color color, lineColor;
  static const whites = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const blacks = {0: 'C#', 1: 'D#', 3: 'F#', 4: 'G#', 5: 'A#'};
  static const aliases = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
    'Cb': 'B',
    'Fb': 'E',
    'B#': 'C',
    'E#': 'F',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty || size.width <= 0 || size.height <= 0) return;
    final selected = {for (final note in notes) aliases[note] ?? note: note};
    final width = size.width / 7;
    final whitePaint = Paint()..color = Colors.white.withValues(alpha: .92);
    final blackPaint = Paint()..color = const Color(0xFF111827);
    final border = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final rect = Rect.fromLTWH(i * width + 1, 1, width - 2, size.height - 2);
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(rounded, whitePaint);
      canvas.drawRRect(rounded, border);
      if (selected.containsKey(whites[i])) {
        _marker(
          canvas,
          selected[whites[i]]!,
          Offset(rect.center.dx, size.height * .8),
          math.min(width * .36, size.height * .13),
        );
      }
    }
    for (final entry in blacks.entries) {
      final rect = Rect.fromLTWH(
        (entry.key + 1) * width - width * .29,
        0,
        width * .58,
        size.height * .61,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        blackPaint,
      );
      if (selected.containsKey(entry.value)) {
        _marker(
          canvas,
          selected[entry.value]!,
          Offset(rect.center.dx, rect.bottom - width * .3),
          math.min(width * .25, size.height * .12),
        );
      }
    }
  }

  void _marker(Canvas canvas, String note, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    final p = TextPainter(
      text: TextSpan(
        text: note,
        style: TextStyle(
          color: Colors.black,
          fontFamily: fontFamily,
          fontSize: math.min(13, radius * (note.length > 1 ? 1.0 : 1.3)),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  @override
  bool shouldRepaint(covariant KeyboardChordPainter oldDelegate) =>
      oldDelegate.fontFamily != fontFamily ||
      oldDelegate.notes.join(',') != notes.join(',') ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor;
}
