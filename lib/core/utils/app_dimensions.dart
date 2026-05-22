import 'package:flutter/material.dart';

/// 기기 화면 크기에 따른 반응형 dimension 유틸.
///
/// 화면 분류:
/// - veryCompact: Z Flip 외부 화면, 매우 작은 기기
/// - compact: Galaxy S8, iPhone SE 등 작은 기기
/// - normal: 일반 안드로이드, iPhone 12 이상
class AppDimensions {
  static const double _compactWidthThreshold = 380;
  static const double _compactHeightThreshold = 740;
  static const double _veryCompactWidthThreshold = 320;
  static const double _veryCompactHeightThreshold = 600;

  /// 좁거나 낮은 화면 (S8급, Z Flip, iPhone SE)
  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < _compactWidthThreshold ||
        size.height < _compactHeightThreshold;
  }

  /// 매우 작은 화면 (Z Flip 외부 화면 등)
  static bool isVeryCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < _veryCompactWidthThreshold ||
        size.height < _veryCompactHeightThreshold;
  }

  /// 텍스트 스케일 (사용자 설정)
  static double textScale(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0);
  }

  /// 하단 안전영역 (탭바 + system inset)
  static double bottomSafe(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }
}

/// 화면 크기에 따른 표준 spacing/sizing 값.
class AppSpacing {
  // 온보딩 로고
  static double onboardingLogoSize(BuildContext context) =>
      AppDimensions.isCompact(context) ? 100 : 140;

  // 카드 이미지 높이
  static double cardImageHeight(BuildContext context) =>
      AppDimensions.isCompact(context) ? 140 : 180;

  // 카드 내부 padding
  static double cardPadding(BuildContext context) =>
      AppDimensions.isCompact(context) ? 12 : 16;

  // 섹션 간격
  static double sectionGap(BuildContext context) =>
      AppDimensions.isCompact(context) ? 16 : 24;

  // 헤더 ↔ 본문 간격
  static double headerGap(BuildContext context) =>
      AppDimensions.isCompact(context) ? 12 : 20;

  // ListView 하단 padding (탭바 가림 방지)
  static double listBottomPadding(BuildContext context) =>
      AppDimensions.bottomSafe(context) + 96;
}
