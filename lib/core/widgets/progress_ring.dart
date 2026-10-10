import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Animated circular progress with rounded caps and an optional gradient.
/// Exposes a semantic label so screen readers announce the value.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 12,
    this.color,
    this.secondaryColor,
    this.trackColor,
    this.child,
    this.semanticLabel,
    this.secondaryProgress,
    this.secondaryRingColor,
  });

  /// 0–1.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;

  /// End colour of the sweep gradient (defaults to [color]).
  final Color? secondaryColor;
  final Color? trackColor;
  final Widget? child;
  final String? semanticLabel;

  /// Optional inner ring (e.g. consistency inside the day counter).
  final double? secondaryProgress;
  final Color? secondaryRingColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final target = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final target2 = secondaryProgress?.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: semanticLabel == null ? '${(target * 100).round()}%' : null,
      excludeSemantics: semanticLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => CustomPaint(
            painter: _RingPainter(
              progress: target * t,
              secondaryProgress: target2 == null ? null : target2 * t,
              strokeWidth: strokeWidth,
              color: color ?? scheme.primary,
              secondaryColor: secondaryColor ?? color ?? scheme.primary,
              trackColor:
                  trackColor ??
                  scheme.surfaceContainerHighest.withValues(alpha: 0.9),
              secondaryRingColor: secondaryRingColor ?? scheme.tertiary,
            ),
            child: child,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(
                strokeWidth * (secondaryProgress == null ? 1.2 : 2.4),
              ),
              // Scale the centre label down rather than overflow at large
              // text sizes; the ring itself carries the semantic label.
              child: child == null
                  ? null
                  : FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.secondaryProgress,
    required this.strokeWidth,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
    required this.secondaryRingColor,
  });

  final double progress;
  final double? secondaryProgress;
  final double strokeWidth;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;
  final Color secondaryRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    _drawRing(
      canvas,
      center,
      radius,
      progress,
      strokeWidth,
      SweepGradient(
        endAngle: math.max(0.01, 2 * math.pi * progress),
        colors: [color, secondaryColor],
        transform: const GradientRotation(-math.pi / 2),
      ),
    );
    if (secondaryProgress != null) {
      final innerStroke = strokeWidth * 0.45;
      final innerRadius = radius - strokeWidth * 0.5 - innerStroke - 4;
      _drawRing(
        canvas,
        center,
        innerRadius,
        secondaryProgress!,
        innerStroke,
        SweepGradient(colors: [secondaryRingColor, secondaryRingColor]),
      );
    }
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double value,
    double stroke,
    Gradient gradient,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.secondaryProgress != secondaryProgress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.secondaryColor != secondaryColor ||
      old.strokeWidth != strokeWidth;
}
