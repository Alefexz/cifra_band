import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loader animado do Cifra Band.
///
/// Efeito: uma luz percorre o contorno do C, o C vai sendo "desenhado"
/// (revelado) a partir da imagem real do logo, em seguida a luz segue
/// para o B e o desenha também. O símbolo fica completo por um instante
/// com um brilho, depois desfaz o desenho (reverso) e recomeça — em loop
/// contínuo enquanto o loader estiver na tela. Não existe bolinha de
/// loading: o próprio ponto de luz que percorre o C/B faz esse papel.
class LogoLoader extends StatefulWidget {
  final double size;

  /// Caminho do asset no pubspec.yaml. Ajuste se for diferente.
  final String assetPath;

  const LogoLoader({
    super.key,
    this.size = 100.0,
    this.assetPath = 'assets/images/logo_symbol_only.png',
  });

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();

    // Ping-pong: 0 -> 1 desenha o símbolo, 1 -> 0 desfaz, e repete.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final ByteData data = await rootBundle.load(widget.assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();

      if (!mounted) return;
      setState(() {
        _image = frame.image;
      });
    } catch (_) {
      // Se o asset não carregar, o painter usa o fallback vetorial.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _CifraBandLoaderPainter(
            progress: _controller.value,
            image: _image,
          ),
        );
      },
    );
  }
}

class _CifraBandLoaderPainter extends CustomPainter {
  final double progress;
  final ui.Image? image;

  _CifraBandLoaderPainter({
    required this.progress,
    required this.image,
  });

  // ============================================================
  // PROGRESSO DA ANIMAÇÃO (dentro de um único trecho 0..1, o
  // AnimationController já cuida do reverse sozinho via repeat(reverse: true))
  //
  // 0.00 -> 0.45 = C sendo formado
  // 0.45 -> 0.82 = B sendo formado
  // 0.82 -> 1.00 = símbolo completo + brilho
  // ============================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double s = math.min(size.width, size.height);
    final Rect bounds = Rect.fromLTWH(
      (size.width - s) / 2,
      (size.height - s) / 2,
      s,
      s,
    );

    double cProgress = 0.0;
    double bProgress = 0.0;
    double completeProgress = 0.0;

    if (progress < 0.45) {
      cProgress = _ease(progress / 0.45);
    } else if (progress < 0.82) {
      cProgress = 1.0;
      bProgress = _ease((progress - 0.45) / 0.37);
    } else {
      cProgress = 1.0;
      bProgress = 1.0;
      completeProgress = _ease((progress - 0.82) / 0.18);
    }

    final ui.Image? img = image;

    if (img != null) {
      _paintLogo(canvas, bounds, img, cProgress, bProgress, completeProgress);
    } else {
      _paintFallback(canvas, bounds, cProgress, bProgress, completeProgress);
    }

    _paintTravelingLight(canvas, bounds, cProgress, bProgress, completeProgress);

    if (completeProgress > 0) {
      _paintFinalGlow(canvas, bounds, completeProgress);
    }
  }

  // ============================================================
  // IMAGEM REAL COMO MÁSCARA
  // ============================================================

  void _paintLogo(
    Canvas canvas,
    Rect bounds,
    ui.Image image,
    double cProgress,
    double bProgress,
    double completeProgress,
  ) {
    final Paint imagePaint = Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withOpacity(0.55 + completeProgress * 0.45);

    final Rect source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    if (cProgress > 0) {
      canvas.save();
      canvas.clipPath(_createCRevealPath(bounds, cProgress));
      canvas.drawImageRect(image, source, bounds, imagePaint);
      canvas.restore();
    }

    if (bProgress > 0) {
      canvas.save();
      canvas.clipPath(_createBRevealPath(bounds, bProgress));
      canvas.drawImageRect(image, source, bounds, imagePaint);
      canvas.restore();
    }

    if (completeProgress > 0) {
      final Paint glowOverlay = Paint()
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withOpacity(completeProgress * 0.20);
      canvas.drawImageRect(image, source, bounds, glowOverlay);
    }
  }

  // ============================================================
  // MÁSCARA DO C (varredura angular)
  // ============================================================

  Path _createCRevealPath(Rect rect, double progress) {
    final double cx = rect.left + rect.width * 0.355;
    final double cy = rect.top + rect.height * 0.565;

    final double outerRadius = rect.width * 0.42;
    final double innerRadius = rect.width * 0.20;

    final double startAngle = -math.pi * 0.98;
    final double sweep = math.pi * 1.96 * progress;

    final List<Offset> outerPoints = [];
    final List<Offset> innerPoints = [];

    const int steps = 80;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double angle = startAngle + sweep * t;

      outerPoints.add(Offset(
        cx + math.cos(angle) * outerRadius,
        cy + math.sin(angle) * outerRadius,
      ));
      innerPoints.add(Offset(
        cx + math.cos(angle) * innerRadius,
        cy + math.sin(angle) * innerRadius,
      ));
    }

    final Path path = Path();
    if (outerPoints.isEmpty) return path;

    path.moveTo(outerPoints.first.dx, outerPoints.first.dy);
    for (final p in outerPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in innerPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    return path;
  }

  // ============================================================
  // MÁSCARA DO B (varredura horizontal da esquerda pra direita)
  // ============================================================

  Path _createBRevealPath(Rect rect, double progress) {
    final double left = rect.left + rect.width * 0.50;
    final double right = rect.left + rect.width * 0.96;
    final double top = rect.top + rect.height * 0.20;
    final double bottom = rect.top + rect.height * 0.96;

    final Rect bArea = Rect.fromLTRB(left, top, right, bottom);

    final double revealWidth = bArea.width * progress;
    final Rect revealRect = Rect.fromLTRB(
      left,
      rect.top,
      left + revealWidth,
      rect.bottom,
    );

    final Path areaPath = Path()..addRect(bArea);
    final Path revealPath = Path()..addRect(revealRect);

    return Path.combine(PathOperation.intersect, areaPath, revealPath);
  }

  // ============================================================
  // LUZ QUE PERCORRE O SÍMBOLO
  // ============================================================

  void _paintTravelingLight(
    Canvas canvas,
    Rect rect,
    double cProgress,
    double bProgress,
    double completeProgress,
  ) {
    if (completeProgress >= 1.0) return;

    final Offset position =
        bProgress <= 0 ? _pointOnC(rect, cProgress) : _pointOnB(rect, bProgress);

    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.amberAccent.withOpacity(0.55),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: position, radius: rect.width * 0.09),
      );

    canvas.drawCircle(position, rect.width * 0.09, glowPaint);

    final Paint corePaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawCircle(position, math.max(1.5, rect.width * 0.018), corePaint);
  }

  Offset _pointOnC(Rect rect, double progress) {
    final double cx = rect.left + rect.width * 0.355;
    final double cy = rect.top + rect.height * 0.565;
    final double radius = rect.width * 0.31;

    final double angle = -math.pi * 0.98 + math.pi * 1.96 * progress;

    return Offset(
      cx + math.cos(angle) * radius,
      cy + math.sin(angle) * radius,
    );
  }

  Offset _pointOnB(Rect rect, double progress) {
    final double left = rect.left + rect.width * 0.50;
    final double top = rect.top + rect.height * 0.20;
    final double bottom = rect.top + rect.height * 0.96;

    return Offset(
      left + rect.width * 0.23,
      top + (bottom - top) * progress,
    );
  }

  // ============================================================
  // BRILHO FINAL (símbolo completo)
  // ============================================================

  void _paintFinalGlow(Canvas canvas, Rect rect, double progress) {
    final double opacity = progress * 0.30;
    if (opacity <= 0) return;

    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.amberAccent.withOpacity(opacity),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: rect.center, radius: rect.width * 0.48),
      );

    canvas.drawCircle(rect.center, rect.width * 0.48, paint);
  }

  // ============================================================
  // FALLBACK VETORIAL (enquanto a imagem não carrega)
  // ============================================================

  void _paintFallback(
    Canvas canvas,
    Rect rect,
    double cProgress,
    double bProgress,
    double completeProgress,
  ) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.075
      ..strokeCap = StrokeCap.round;

    paint.color = Colors.white.withOpacity(0.85);
    final Rect cRect = Rect.fromCircle(
      center: Offset(
        rect.left + rect.width * 0.35,
        rect.top + rect.height * 0.55,
      ),
      radius: rect.width * 0.28,
    );
    canvas.drawArc(cRect, -math.pi * 0.85, math.pi * 1.7 * cProgress, false, paint);

    paint.color = Colors.amber.withOpacity(0.9);
    final Rect bRect = Rect.fromLTRB(
      rect.left + rect.width * 0.55,
      rect.top + rect.height * 0.28,
      rect.right - rect.width * 0.08,
      rect.bottom - rect.height * 0.10,
    );
    if (bProgress > 0) {
      canvas.drawArc(bRect, -math.pi / 2, math.pi * bProgress, false, paint);
    }
  }

  double _ease(double value) {
    return Curves.easeInOutCubic.transform(value.clamp(0.0, 1.0));
  }

  @override
  bool shouldRepaint(covariant _CifraBandLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.image != image;
  }
}