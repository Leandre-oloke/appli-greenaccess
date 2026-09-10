import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/score_climat_model.dart';

double _rad(double degrees) => degrees * math.pi / 180.0;
import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_motion.dart';
import '../tokens/ga_score_scale.dart';
import '../tokens/ga_typography.dart';
import 'ga_badge_pill.dart';

/// Peintre de l'arc de jauge (partagé par [GaScoreGauge] et [GaMiniGauge]).
class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.gradient,
    required this.glowColor,
    required this.stroke,
    required this.sweepDegrees,
    required this.showTicks,
    required this.tickColor,
  });

  final double progress; // 0..1
  final Color trackColor;
  final SweepGradient gradient;
  final Color glowColor;
  final double stroke;
  final double sweepDegrees;
  final bool showTicks;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final startAngle = (math.pi / 2) + _rad((360 - sweepDegrees) / 2);
    final sweep = _rad(sweepDegrees);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, sweep, false, track);

    if (progress > 0) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(arcRect, startAngle, sweep * progress, false, glow);

      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(arcRect);
      canvas.drawArc(arcRect, startAngle, sweep * progress, false, prog);
    }

    if (showTicks) {
      const ticks = 10;
      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i <= ticks; i++) {
        final a = startAngle + sweep * (i / ticks);
        final outer = center +
            Offset(math.cos(a), math.sin(a)) * (radius + stroke / 2 - 1);
        final inner = center +
            Offset(math.cos(a), math.sin(a)) * (radius + stroke / 2 - 6);
        canvas.drawLine(inner, outer, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.glowColor != glowColor;
}

/// Jauge de score signature (Score Climat 0–100).
class GaScoreGauge extends StatelessWidget {
  const GaScoreGauge({
    super.key,
    required this.score,
    this.max = 100,
    this.level,
    this.size = 220,
    this.animate = true,
    this.showLevelPill = true,
  });

  final double score;
  final double max;
  final NiveauScore? level;
  final double size;
  final bool animate;
  final bool showLevelPill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.gaTokens;
    final niveau = level ?? ScoreClimatModel.niveauFromScore(score);
    final bandColor = GaScoreScale.colorFor(niveau, theme.brightness);
    final target = (max <= 0 ? 0.0 : score / max).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (animate && !reduce) ? target : target),
        duration: (animate && !reduce) ? GaMotion.gauge : Duration.zero,
        curve: GaMotion.decelerate,
        builder: (context, value, _) {
          final shown = ((animate && !reduce) ? value * max : score);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _GaugePainter(
                  progress: (animate && !reduce) ? value : target,
                  trackColor: tokens.forestContainer,
                  gradient: context.gaGradients.gaugeSweep,
                  glowColor: bandColor,
                  stroke: size * 0.11,
                  sweepDegrees: 260,
                  showTicks: true,
                  tickColor: tokens.outline,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shown.round().toString(),
                    style: GaTypography.numeric(tokens,
                        size: size * 0.24, color: bandColor),
                  ),
                  Text('/ ${max.round()}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: tokens.inkSoft)),
                  if (showLevelPill) ...[
                    const SizedBox(height: 8),
                    GaBadgePill(
                      label: GaScoreScale.labelFor(niveau),
                      color: bandColor,
                      filled: true,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Variante anneau fin (dashboard, historique).
class GaMiniGauge extends StatelessWidget {
  const GaMiniGauge({
    super.key,
    required this.score,
    this.max = 100,
    this.size = 88,
    this.level,
    this.animate = true,
  });

  final double score;
  final double max;
  final double size;
  final NiveauScore? level;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.gaTokens;
    final niveau = level ?? ScoreClimatModel.niveauFromScore(score);
    final bandColor = GaScoreScale.colorFor(niveau, theme.brightness);
    final target = (max <= 0 ? 0.0 : score / max).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: (animate && !reduce)
            ? const Duration(milliseconds: 900)
            : Duration.zero,
        curve: GaMotion.decelerate,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _GaugePainter(
                progress: value,
                trackColor: tokens.forestContainer,
                gradient: context.gaGradients.gaugeSweep,
                glowColor: bandColor,
                stroke: size * 0.10,
                sweepDegrees: 300,
                showTicks: false,
                tickColor: tokens.outline,
              ),
            ),
            Text(
              (value * max).round().toString(),
              style: GaTypography.numeric(tokens,
                  size: size * 0.30, color: bandColor),
            ),
          ],
        ),
      ),
    );
  }
}
