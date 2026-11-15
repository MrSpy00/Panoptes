import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/panoptes_theme.dart';

/// Continuously animated Argos Panoptes emblem with soft, smooth gaze & iris breathing
class AnimatedPanoptesLogo extends StatefulWidget {
  final double size;
  final bool simplified;
  final bool showReticle;

  const AnimatedPanoptesLogo({
    super.key,
    this.size = 54,
    this.simplified = false,
    this.showReticle = true,
  });

  @override
  State<AnimatedPanoptesLogo> createState() => _AnimatedPanoptesLogoState();
}

class _AnimatedPanoptesLogoState extends State<AnimatedPanoptesLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
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
      builder: (context, _) {
        return PanoptesLogo(
          size: widget.size,
          simplified: widget.simplified,
          showReticle: widget.showReticle,
          scanPulse: _controller.value,
        );
      },
    );
  }
}

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
    _SatelliteEyeSpec(
      cx: 0.24,
      cy: 0.30,
      rx: 0.098,
      ry: 0.052,
      gazeDx: -0.016,
      gazeDy: -0.004,
      opacity: 0.68,
    ),
    _SatelliteEyeSpec(
      cx: 0.76,
      cy: 0.30,
      rx: 0.098,
      ry: 0.052,
      gazeDx: 0.016,
      gazeDy: -0.006,
      opacity: 0.68,
    ),
    _SatelliteEyeSpec(
      cx: 0.24,
      cy: 0.70,
      rx: 0.098,
      ry: 0.052,
      gazeDx: -0.014,
      gazeDy: 0.009,
      opacity: 0.60,
    ),
    _SatelliteEyeSpec(
      cx: 0.76,
      cy: 0.70,
      rx: 0.098,
      ry: 0.052,
      gazeDx: 0.015,
      gazeDy: 0.005,
      opacity: 0.60,
    ),
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
    final phase = scanPulse * math.pi * 2;
    final breath = 0.5 + 0.5 * math.sin(phase);

    // 1. Pure Pitch-Black Obsidian Base
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(minDim * 0.16),
    );
    canvas.drawRRect(bgRect, Paint()..color = PanoptesColors.obsidian);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = PanoptesColors.borderCrimson.withValues(alpha: 0.55 + 0.30 * breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, minDim * 0.015),
    );

    // 2. Geometric Surveillance Reticle (when full mode)
    if (showReticle && !simplified) {
      final ringPaint = Paint()
        ..color = PanoptesColors.burgundyDeep.withValues(alpha: 0.25 + 0.20 * breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, minDim * 0.008);
      canvas.drawCircle(center, minDim * (0.42 + 0.015 * breath), ringPaint);
      canvas.drawCircle(center, minDim * 0.29, ringPaint);

      final tickPaint = Paint()
        ..color = PanoptesColors.crimson.withValues(alpha: 0.40 + 0.25 * breath)
        ..strokeWidth = math.max(1.0, minDim * 0.012);
      canvas.drawLine(Offset(w * 0.5, h * 0.04), Offset(w * 0.5, h * 0.10), tickPaint);
      canvas.drawLine(Offset(w * 0.5, h * 0.90), Offset(w * 0.5, h * 0.96), tickPaint);
      canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.10, h * 0.5), tickPaint);
      canvas.drawLine(Offset(w * 0.90, h * 0.5), Offset(w * 0.96, h * 0.5), tickPaint);
    }

    // 3. Draw Satellite Eyes with soft phase-shifted gaze motion
    final satellites = simplified ? _compactSatellites : _fullSatellites;
    for (int i = 0; i < satellites.length; i++) {
      final sat = satellites[i];
      final satShift = math.sin(phase + i * 0.8) * 0.007;
      _drawGeometricEye(
        canvas: canvas,
        size: size,
        cx: sat.cx * w,
        cy: sat.cy * h,
        rx: sat.rx * w,
        ry: sat.ry * h,
        irisOffset: Offset((sat.gazeDx + satShift) * w, sat.gazeDy * h),
        opacity: (sat.opacity + 0.08 * math.cos(phase + i)).clamp(0.3, 1.0),
        isCentral: false,
        slitPupil: sat.slitPupil,
      );
    }

    // 4. Draw Central Sovereign Eye of Argos Panoptes
    final pulseOffsetX = math.sin(phase) * (w * 0.014);
    final pulseOffsetY = math.cos(phase * 2) * (h * 0.005);
    _drawGeometricEye(
      canvas: canvas,
      size: size,
      cx: w * 0.50,
      cy: h * 0.50,
      rx: simplified ? w * 0.36 : w * 0.255,
      ry: simplified ? h * 0.21 : h * 0.145,
      irisOffset: Offset(pulseOffsetX, pulseOffsetY),
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
      canvas.drawPath(
        eyePath,
        Paint()..color = const Color(0xFF050508),
      );
    }

    final contourPaint = Paint()
      ..color = const Color(0xFFF4F4F5).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = isCentral
          ? math.max(1.8, minDim * 0.032)
          : math.max(1.1, minDim * 0.019);
    canvas.drawPath(eyePath, contourPaint);

    final irisCenter = Offset(cx + irisOffset.dx, cy + irisOffset.dy);
    final irisRadius = isCentral ? ry * 0.66 : ry * 0.62;

    final irisPaint = Paint()
      ..color = (isCentral ? PanoptesColors.crimson : PanoptesColors.burgundy)
          .withValues(alpha: math.min(1.0, opacity + 0.12))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCentral
          ? math.max(1.6, minDim * 0.028)
          : math.max(1.0, minDim * 0.017);
    canvas.drawCircle(irisCenter, irisRadius, irisPaint);

    if (isCentral && !simplified) {
      canvas.drawCircle(
        irisCenter,
        irisRadius * 0.68,
        Paint()
          ..color = PanoptesColors.burgundyDeep.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, minDim * 0.014),
      );
    }

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
