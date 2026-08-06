import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'exhibition_api.dart';
import 'exhibition_model.dart';

// ── 거리 필터 상수 ────────────────────────────────────────────────────────────

/// 주 반경: 이 안의 전부 표시 (정상 지역)
const double kNearRadiusKm = 50.0;

/// 희소 지역 판단 기준: 이 미만이면 반경 확장
const int kMinItems = 5;

/// 확장 시 채우려는 목표 개수
const int kFillTarget = 10;

/// 1차 확장 반경
const double kMidRadiusKm = 100.0;

/// 2차 확장 반경
const double kFarRadiusKm = 150.0;

/// 밀집 상황 안전 상한
const int kHardCap = 50;

/// 위치 없을 때 상한
const int kNoLocCap = 15;

// ── 시도명 변환 ──────────────────────────────────────────────────────────────

/// GPS 좌표를 문화정보 API sido 파라미터로 변환
/// 좌표 범위 매핑 방식 (역지오코딩 라이브러리 불필요)
/// 참고: sido 파라미터는 서버 필터로 신뢰 불가 — 앱 내부 거리 필터로 처리
String latLngToSido(double lat, double lng) {
  // 제주
  if (lat >= 33.0 && lat <= 34.0 && lng >= 126.0 && lng <= 127.0) return '제주';
  // 부산
  if (lat >= 34.8 && lat <= 35.4 && lng >= 128.7 && lng <= 129.4) return '부산';
  // 대구
  if (lat >= 35.6 && lat <= 36.1 && lng >= 128.4 && lng <= 129.0) return '대구';
  // 인천
  if (lat >= 37.2 && lat <= 37.7 && lng >= 126.3 && lng <= 126.8) return '인천';
  // 광주
  if (lat >= 35.0 && lat <= 35.3 && lng >= 126.7 && lng <= 127.0) return '광주';
  // 대전
  if (lat >= 36.2 && lat <= 36.5 && lng >= 127.2 && lng <= 127.6) return '대전';
  // 울산
  if (lat >= 35.4 && lat <= 35.7 && lng >= 129.0 && lng <= 129.5) return '울산';
  // 세종
  if (lat >= 36.4 && lat <= 36.7 && lng >= 127.1 && lng <= 127.4) return '세종';
  // 서울
  if (lat >= 37.4 && lat <= 37.7 && lng >= 126.7 && lng <= 127.2) return '서울';
  // 경기
  if (lat >= 36.9 && lat <= 38.3 && lng >= 126.3 && lng <= 127.9) return '경기';
  // 강원
  if (lat >= 37.0 && lat <= 38.6 && lng >= 127.5 && lng <= 129.4) return '강원';
  // 충북
  if (lat >= 36.0 && lat <= 37.2 && lng >= 127.4 && lng <= 128.5) return '충북';
  // 충남
  if (lat >= 36.0 && lat <= 37.0 && lng >= 126.1 && lng <= 127.4) return '충남';
  // 전북
  if (lat >= 35.3 && lat <= 36.2 && lng >= 126.3 && lng <= 127.7) return '전북';
  // 전남
  if (lat >= 34.0 && lat <= 35.4 && lng >= 126.0 && lng <= 127.8) return '전남';
  // 경북
  if (lat >= 35.7 && lat <= 37.1 && lng >= 128.2 && lng <= 129.6) return '경북';
  // 경남
  if (lat >= 34.6 && lat <= 35.7 && lng >= 127.5 && lng <= 129.2) return '경남';
  // 기본값: 서울
  return '서울';
}

// ── 위치 + 문화행사 목록 상태 ─────────────────────────────────────────────────

class ExhibitionState {
  final List<Exhibition> items;
  final bool isLoading;
  final bool hasLocation;
  final double? userLat;
  final double? userLng;

  const ExhibitionState({
    this.items = const [],
    this.isLoading = false,
    this.hasLocation = false,
    this.userLat,
    this.userLng,
  });

  ExhibitionState copyWith({
    List<Exhibition>? items,
    bool? isLoading,
    bool? hasLocation,
    double? userLat,
    double? userLng,
  }) =>
      ExhibitionState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        hasLocation: hasLocation ?? this.hasLocation,
        userLat: userLat ?? this.userLat,
        userLng: userLng ?? this.userLng,
      );
}

class ExhibitionNotifier extends AsyncNotifier<ExhibitionState> {
  @override
  Future<ExhibitionState> build() async {
    return _load();
  }

  Future<ExhibitionState> _load() async {
    if (kDebugMode) print('EXH: _load start');
    double? userLat;
    double? userLng;
    bool hasLocation = false;
    String sido = '서울'; // 기본값: 서울

    // 위치 권한 확인 및 좌표 획득
    // 위치 획득에 실패해도 서울 기준 API 호출은 반드시 진행
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.deniedForever &&
          perm != LocationPermission.denied) {
        // Future.timeout으로 독립 제어 (일부 Android에서 timeLimit 무시 방지)
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('location timeout'),
        );
        userLat = pos.latitude;
        userLng = pos.longitude;
        hasLocation = true;
        sido = latLngToSido(pos.latitude, pos.longitude);
        dev.log('[ExhibitionProvider] sido=$sido', name: 'Exhibition');
      }
    } on TimeoutException {
      if (kDebugMode) print('EXH: location timeout — fallback to 서울');
      dev.log('[ExhibitionProvider] location timeout', name: 'Exhibition');
    } catch (e) {
      if (kDebugMode) print('EXH: location error=$e — fallback to 서울');
      dev.log('[ExhibitionProvider] location error: $e', name: 'Exhibition');
    }

    if (kDebugMode) print('EXH: sido=$sido hasLocation=$hasLocation');

    // API 호출: numOfrows=100 단일 호출
    final result = await ExhibitionApi.instance.fetchExhibitions(sido);
    if (kDebugMode) print('EXH: api returned ${result?.length ?? "null"}');

    if (result == null) {
      if (kDebugMode) print('EXH: result null — section hidden');
      return ExhibitionState(
        items: const [],
        isLoading: false,
        hasLocation: hasLocation,
        userLat: userLat,
        userLng: userLng,
      );
    }

    // ── 거리 필터 및 표시 개수 결정 ─────────────────────────────────────────
    List<Exhibition> finalItems;

    if (hasLocation && userLat != null && userLng != null) {
      final lat = userLat;
      final lng = userLng;

      // 좌표 있는 item만 거리 계산 (무좌표 item 제외)
      final withDist = result
          .where((e) => e.latitude != null && e.longitude != null)
          .map((e) => (
                item: e,
                dist: ExhibitionApi.distanceKm(
                    lat, lng, e.latitude!, e.longitude!),
              ))
          .toList()
        ..sort((a, b) => a.dist.compareTo(b.dist));

      // 케이스 A: 위치 있음
      final within50 =
          withDist.where((e) => e.dist <= kNearRadiusKm).toList();

      String radiusUsed;
      List<Exhibition> selected;

      if (within50.length >= kMinItems) {
        // 정상 지역: 50km 이내 전부 (최대 kHardCap)
        selected = within50.take(kHardCap).map((e) => e.item).toList();
        radiusUsed = '50km';
      } else {
        // 희소 지역: 목표 kFillTarget개 채우기
        final near100 =
            withDist.where((e) => e.dist <= kMidRadiusKm).toList();
        if (near100.length >= kFillTarget) {
          selected =
              near100.take(kFillTarget).map((e) => e.item).toList();
          radiusUsed = '100km';
        } else {
          final near150 =
              withDist.where((e) => e.dist <= kFarRadiusKm).toList();
          selected =
              near150.take(kFillTarget).map((e) => e.item).toList();
          radiusUsed = '150km';
        }
      }

      if (kDebugMode) {
        print(
            'EXH: within50=${within50.length} final=${selected.length} radiusUsed=$radiusUsed');
      }

      if (selected.isEmpty) {
        if (kDebugMode) print('EXH: 거리 필터 후 0건 — section hidden');
        return ExhibitionState(
          items: const [],
          isLoading: false,
          hasLocation: hasLocation,
          userLat: userLat,
          userLng: userLng,
        );
      }

      finalItems = selected;
    } else {
      // 케이스 B: 위치 없음/거부 — endDate 임박순 → startDate 빠른순, 최대 kNoLocCap
      final sorted = List<Exhibition>.from(result)
        ..sort((a, b) {
          final cmp = a.endDate.compareTo(b.endDate);
          return cmp != 0 ? cmp : a.startDate.compareTo(b.startDate);
        });
      finalItems = sorted.take(kNoLocCap).toList();
      if (kDebugMode) {
        print('EXH: no location — date sorted final=${finalItems.length}');
      }
    }

    return ExhibitionState(
      items: finalItems,
      isLoading: false,
      hasLocation: hasLocation,
      userLat: userLat,
      userLng: userLng,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load());
  }
}

final exhibitionProvider =
    AsyncNotifierProvider<ExhibitionNotifier, ExhibitionState>(
  ExhibitionNotifier.new,
);
