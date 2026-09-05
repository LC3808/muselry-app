import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../features/badge/badge_model.dart';

/// 전국 국립박물관 Badge의 공통 souvenir medallion입니다.
///
/// 3종 prototype(중앙·경주·제주)은 CustomPainter로 서로 다른 지역 상징을
/// 표현하며, 나머지 박물관은 동일한 placeholder 문법을 유지합니다.
class NationalMuseumBadgeMedal extends StatelessWidget {
  final BadgeProgress badge;
  final double size;

  const NationalMuseumBadgeMedal({
    required this.badge,
    required this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visualKey = badge.definition.visualKey;
    final isPrototype = _MuseumMedalStyle.isPrototype(visualKey);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _NationalMuseumMedalPainter(
              visualKey: visualKey,
              isEarned: badge.isEarned,
            ),
          ),
          if (!badge.isEarned)
            Icon(
              Icons.lock_outline_rounded,
              size: size * 0.31,
              color: const Color(0xFFF2F2F3).withValues(alpha: 0.32),
            )
          else if (!isPrototype)
            Icon(
              Icons.account_balance_outlined,
              size: size * 0.34,
              color: const Color(0xFFF2F2F3).withValues(alpha: 0.90),
            ),
        ],
      ),
    );
  }
}

class _NationalMuseumMedalPainter extends CustomPainter {
  final String visualKey;
  final bool isEarned;

  const _NationalMuseumMedalPainter({
    required this.visualKey,
    required this.isEarned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final style = _MuseumMedalStyle.fromVisualKey(visualKey);
    final outerRadius = radius * 0.95;
    final innerRadius = radius * 0.78;

    final outerFill = Paint()
      ..color = isEarned ? style.background : const Color(0xFF252527);
    canvas.drawCircle(center, outerRadius, outerFill);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..color = isEarned
          ? const Color(0xFFE8A87C).withValues(alpha: 0.94)
          : const Color(0xFFF2F2F3).withValues(alpha: 0.16);
    canvas.drawCircle(center, outerRadius - radius * 0.045, rim);

    final innerFill = Paint()
      ..color = isEarned ? style.innerBackground : const Color(0xFF19191B);
    canvas.drawCircle(center, innerRadius, innerFill);

    final innerRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius * 0.028)
      ..color = isEarned
          ? const Color(0xFFF2F2F3).withValues(alpha: 0.20)
          : const Color(0xFFF2F2F3).withValues(alpha: 0.08);
    canvas.drawCircle(center, innerRadius, innerRim);

    if (isEarned && _MuseumMedalStyle.isPrototype(visualKey)) {
      _drawPrototypeMotif(canvas, center, radius, style);
    }
  }

  void _drawPrototypeMotif(
    Canvas canvas,
    Offset center,
    double radius,
    _MuseumMedalStyle style,
  ) {
    final paint = Paint()
      ..color = style.motif
      ..style = PaintingStyle.fill;

    switch (visualKey) {
      case 'central':
        _drawPensiveBodhisattva(canvas, center, radius, paint);
      case 'gyeongju':
        _drawSillaCrown(canvas, center, radius, paint);
      case 'jeju':
        _drawDolhareubang(canvas, center, radius, paint);
    }
  }

  void _drawPensiveBodhisattva(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final head = Offset(center.dx + radius * 0.12, center.dy - radius * 0.28);
    canvas.drawCircle(head, radius * 0.12, paint);

    final body = Path()
      ..moveTo(center.dx - radius * 0.12, center.dy - radius * 0.12)
      ..quadraticBezierTo(
        center.dx + radius * 0.02,
        center.dy - radius * 0.02,
        center.dx + radius * 0.10,
        center.dy + radius * 0.20,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.30,
        center.dy + radius * 0.30,
        center.dx + radius * 0.18,
        center.dy + radius * 0.45,
      )
      ..lineTo(center.dx - radius * 0.30, center.dy + radius * 0.45)
      ..quadraticBezierTo(
        center.dx - radius * 0.12,
        center.dy + radius * 0.24,
        center.dx - radius * 0.20,
        center.dy + radius * 0.04,
      )
      ..close();
    canvas.drawPath(body, paint);

    final arm = Paint()
      ..color = paint.color.withValues(alpha: 0.86)
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius * 0.12, center.dy - radius * 0.05),
      Offset(center.dx + radius * 0.12, center.dy - radius * 0.20),
      arm,
    );
  }

  void _drawSillaCrown(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final crown = Path()
      ..moveTo(center.dx - radius * 0.39, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius * 0.33, center.dy - radius * 0.20)
      ..lineTo(center.dx - radius * 0.20, center.dy - radius * 0.05)
      ..lineTo(center.dx - radius * 0.12, center.dy - radius * 0.42)
      ..lineTo(center.dx, center.dy - radius * 0.11)
      ..lineTo(center.dx + radius * 0.13, center.dy - radius * 0.46)
      ..lineTo(center.dx + radius * 0.22, center.dy - radius * 0.06)
      ..lineTo(center.dx + radius * 0.36, center.dy - radius * 0.24)
      ..lineTo(center.dx + radius * 0.39, center.dy + radius * 0.28)
      ..close();
    canvas.drawPath(crown, paint);

    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.25),
        width: radius * 0.86,
        height: radius * 0.16,
      ),
      Radius.circular(radius * 0.05),
    );
    canvas.drawRRect(band, paint);
  }

  void _drawDolhareubang(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.06),
        width: radius * 0.52,
        height: radius * 0.82,
      ),
      Radius.circular(radius * 0.18),
    );
    canvas.drawRRect(body, paint);

    final hat = Paint()..color = paint.color.withValues(alpha: 0.86);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - radius * 0.37),
        width: radius * 0.62,
        height: radius * 0.22,
      ),
      hat,
    );

    final face = Paint()..color = const Color(0xFF1C2D2A);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.11, center.dy - radius * 0.06),
      radius * 0.045,
      face,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.11, center.dy - radius * 0.06),
      radius * 0.045,
      face,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.12, center.dy + radius * 0.17),
      Offset(center.dx + radius * 0.12, center.dy + radius * 0.17),
      face
        ..strokeWidth = radius * 0.04
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NationalMuseumMedalPainter oldDelegate) {
    return oldDelegate.visualKey != visualKey ||
        oldDelegate.isEarned != isEarned;
  }
}

class _MuseumMedalStyle {
  final Color background;
  final Color innerBackground;
  final Color motif;

  const _MuseumMedalStyle({
    required this.background,
    required this.innerBackground,
    required this.motif,
  });

  static bool isPrototype(String visualKey) {
    return visualKey == 'central' ||
        visualKey == 'gyeongju' ||
        visualKey == 'jeju';
  }

  static _MuseumMedalStyle fromVisualKey(String visualKey) {
    switch (visualKey) {
      case 'central':
        return const _MuseumMedalStyle(
          background: Color(0xFF172941),
          innerBackground: Color(0xFF0F1B2D),
          motif: Color(0xFFF0D59B),
        );
      case 'gyeongju':
        return const _MuseumMedalStyle(
          background: Color(0xFF45233B),
          innerBackground: Color(0xFF2B1427),
          motif: Color(0xFFF0C66B),
        );
      case 'jeju':
        return const _MuseumMedalStyle(
          background: Color(0xFF1E4A43),
          innerBackground: Color(0xFF102D29),
          motif: Color(0xFFB99B73),
        );
      default:
        return const _MuseumMedalStyle(
          background: Color(0xFF303034),
          innerBackground: Color(0xFF202024),
          motif: Color(0xFFF2F2F3),
        );
    }
  }
}
