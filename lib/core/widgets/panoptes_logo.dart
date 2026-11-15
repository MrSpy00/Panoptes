import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/panoptes_theme.dart';

/// Argos Panoptes Multi-Eye Geometric Emblem
/// Implements the exact mythological & visual specification:
/// - Pure #000000 pitch-black core
/// - Central sharp geometric eye with Crimson-Burgundy (#E11D48 / #9F1239) iris & slit pupil
/// - 8 surrounding geometric satellite eyes at varied sizes, opacities (depth), and gaze angles
/// - Simplified 3-eye mode for 24px-48px compact icons
class PanoptesLogo extends StatelessWidget {
  final double size;
  final bool simplified;
  final bool showReticle;
  final double scanPulse;

  const PanoptesLogo({
    super.key,
    this.size = 72,
    this.simplified = false,
    this.showReticle = true,
    this.scanPulse = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final useSimplified = simplified || size <= 42;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PanoptesMultiEyePainter(
          simplified: useSimplified,
          showReticle: showReticle,
          scanPulse: scanPulse,
        ),
      ),
    );
  }
}

class _SatelliteEyeSpec {
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double gazeDx;
  final double gazeDy;
  final double opacity;
  final bool slitPupil;

  const _SatelliteEyeSpec({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.gazeDx,
    required this.gazeDy,
    required this.opacity,
    this.slitPupil = false,
  });
}

class _PanoptesMultiEyePainter extends CustomPainter {
  final bool simplified;
  final bool showReticle;
  final double scanPulse;

  const _PanoptesMultiEyePainter({
    required this.simplified,
    required this.showReticle,
    required this.scanPulse,
  });

  static const List<_SatelliteEyeSpec> _fullSatellites = [
    // 1. Top Crown Eye (gazing slightly down-left)
    _SatelliteEyeSpec(
      cx: 0.50,
      cy: 0.20,
      rx: 0.125,
      ry: 0.068,
      gazeDx: -0.012,
      gazeDy: 0.008,
      opacity: 0.85,
      slitPupil: true,
    ),
    // 2. Bottom Anchor Eye (gazing slightly up-right)
    _SatelliteEyeSpec(
      cx: 0.50,
      cy: 0.80,
      rx: 0.125,
      ry: 0.068,
      gazeDx: 0.012,
      gazeDy: -0.008,
      opacity: 0.85,
      slitPupil: true,
    ),
    // 3. Upper-Left Sentinel (gazing left)
    _SatelliteEyeSpec(
      cx: 0.24,
      cy: 0.30,
      rx: 0.098,
      ry: 0.052,
      gazeDx: -0.016,
      gazeDy: -0.004,
      opacity: 0.68,
    ),
    // 4. Upper-Right Sentinel (gazing up-right)
    _SatelliteEyeSpec(
      cx: 0.76,
      cy: 0.30,
      rx: 0.098,
      ry: 0.052,
      gazeDx: 0.016,
      gazeDy: -0.006,
      opacity: 0.68,
    ),
    // 5. Lower-Left Watcher (gazing down-left)
    _SatelliteEyeSpec(
      cx: 0.24,
      cy: 0.70,
      rx: 0.098,
      ry: 0.052,
      gazeDx: -0.014,
      gazeDy: 0.009,
      opacity: 0.60,
    ),
    // 6. Lower-Right Watcher (gazing right)
    _SatelliteEyeSpec(
      cx: 0.76,
      cy: 0.70,
      rx: 0.098,
      ry: 0.052,
      gazeDx: 0.015,
      gazeDy: 0.005,
      opacity: 0.60,
    ),
    // 7. Far-Left Peripheral (small, low opacity for depth)
    _SatelliteEyeSpec(
      cx: 0.135,
      cy: 0.50,
      rx: 0.074,
      ry: 0.040,
      gazeDx: -0.012,
      gazeDy: 0.0,
      opacity: 0.42,
      slitPupil: true,
    ),
    // 8. Far-Right Peripheral (small, low opacity for depth)
    _SatelliteEyeSpec(
      cx: 0.865,
      cy: 0.50,
      rx: 0.074,
      ry: 0.040,
      gazeDx: 0.012,
      gazeDy: 0.0,
      opacity: 0.42,
      slitPupil: true,
    ),
  ];

  static const List<_SatelliteEyeSpec> _compactSatellites = [
    _SatelliteEyeSpec(
      cx: 0.50,
      cy: 0.21,
      rx: 0.18,
      ry: 0.085,
      gazeDx: -0.015,
      gazeDy: 0.0,
      opacity: 0.78,
    ),
    _SatelliteEyeSpec(
      cx: 0.50,
      cy: 0.79,
      rx: 0.18,
      ry: 0.085,
      gazeDx: 0.015,
      gazeDy: 0.0,
      opacity: 0.78,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minDim = math.min(w, h);
    final center = Offset(w / 2, h / 2);

    // 1. Pure Pitch-Black Obsidian Base
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(minDim * 0.16),
    );
    canvas.drawRRect(bgRect, Paint()..color = PanoptesColors.obsidian);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = PanoptesColors.borderCrimson.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, minDim * 0.015),
    );

    // 2. Geometric Surveillance Reticle (when full mode)
    if (showReticle && !simplified) {
      final ringPaint = Paint()
        ..color = PanoptesColors.burgundyDeep.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, minDim * 0.008);
      canvas.drawCircle(center, minDim * 0.43, ringPaint);
      canvas.drawCircle(center, minDim * 0.29, ringPaint);

      final tickPaint = Paint()
        ..color = PanoptesColors.crimson.withValues(alpha: 0.45)
        ..strokeWidth = math.max(1.0, minDim * 0.012);
      canvas.drawLine(Offset(w * 0.5, h * 0.04), Offset(w * 0.5, h * 0.10), tickPaint);
      canvas.drawLine(Offset(w * 0.5, h * 0.90), Offset(w * 0.5, h * 0.96), tickPaint);
      canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.10, h * 0.5), tickPaint);
      canvas.drawLine(Offset(w * 0.90, h * 0.5), Offset(w * 0.96, h * 0.5), tickPaint);
    }

    // 3. Draw Satellite Eyes
    final satellites = simplified ? _compactSatellites : _fullSatellites;
    for (final sat in satellites) {
      _drawGeometricEye(
        canvas: canvas,
        size: size,
        cx: sat.cx * w,
        cy: sat.cy * h,
        rx: sat.rx * w,
        ry: sat.ry * h,
        irisOffset: Offset(sat.gazeDx * w, sat.gazeDy * h),
        opacity: sat.opacity,
        isCentral: false,
        slitPupil: sat.slitPupil,
      );
    }

    // 4. Draw Central Sovereign Eye of Argos Panoptes
    final pulseOffset = math.sin(scanPulse * math.pi * 2) * (w * 0.012);
    _drawGeometricEye(
      canvas: canvas,
      size: size,
      cx: w * 0.50,
      cy: h * 0.50,
      rx: simplified ? w * 0.36 : w * 0.255,
      ry: simplified ? h * 0.21 : h * 0.145,
      irisOffset: Offset(pulseOffset, 0),
      opacity: 1.0,
      isCentral: true,
      slitPupil: true,
    );
  }

  void _drawGeometricEye({
    required Canvas canvas,
    required Size size,
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Offset irisOffset,
    required double opacity,
    required bool isCentral,
    required bool slitPupil,
  }) {
    final minDim = math.min(size.width, size.height);
    final eyePath = Path()
      ..moveTo(cx - rx, cy)
      ..quadraticBezierTo(cx, cy - ry * 1.45, cx + rx, cy)
      ..quadraticBezierTo(cx, cy + ry * 1.45, cx - rx, cy)
      ..close();

    if (isCentral) {
      // Dark interior fill so central eye cuts cleanly over any reticle lines
      canvas.drawPath(
        eyePath,
        Paint()..color = const Color(0xFF050508),
      );
    }

    // Sharp White/Light-Gray Stroke Contour
    final contourPaint = Paint()
      ..color = const Color(0xFFF4F4F5).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = isCentral
          ? math.max(1.8, minDim * 0.032)
          : math.max(1.1, minDim * 0.019);
    canvas.drawPath(eyePath, contourPaint);

    // Iris Center (with subtle gaze vector)
    final irisCenter = Offset(cx + irisOffset.dx, cy + irisOffset.dy);
    final irisRadius = isCentral ? ry * 0.66 : ry * 0.62;

    // Crimson-Burgundy Iris Ring (Stroke-focused)
    final irisPaint = Paint()
      ..color = (isCentral ? PanoptesColors.crimson : PanoptesColors.burgundy)
          .withValues(alpha: math.min(1.0, opacity + 0.12))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCentral
          ? math.max(1.6, minDim * 0.028)
          : math.max(1.0, minDim * 0.017);
    canvas.drawCircle(irisCenter, irisRadius, irisPaint);

    if (isCentral && !simplified) {
      // Inner Deep Burgundy Ring
      canvas.drawCircle(
        irisCenter,
        irisRadius * 0.68,
        Paint()
          ..color = PanoptesColors.burgundyDeep.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, minDim * 0.014),
      );
    }

    // Pupil (Sharp vertical slit or geometric core)
    if (slitPupil) {
      final slitHalf = irisRadius * 0.76;
      canvas.drawLine(
        Offset(irisCenter.dx, irisCenter.dy - slitHalf),
        Offset(irisCenter.dx, irisCenter.dy + slitHalf),
        Paint()
          ..color = const Color(0xFFF4F4F5).withValues(alpha: opacity)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = isCentral
              ? math.max(1.6, minDim * 0.026)
              : math.max(1.0, minDim * 0.016),
      );
      if (isCentral) {
        canvas.drawCircle(
          irisCenter,
          irisRadius * 0.22,
          Paint()..color = PanoptesColors.crimson,
        );
      }
    } else {
      canvas.drawCircle(
        irisCenter,
         math.max(1.3, irisRadius * 0.30),
        Paint()..color = const Color(0xFFF4F4F5).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PanoptesMultiEyePainter oldDelegate) {
    return oldDelegate.simplified != simplified ||
        oldDelegate.showReticle != showReticle ||
        oldDelegate.scanPulse != scanPulse;
  }
}
