import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'exhibition_api.dart';
import 'exhibition_model.dart';

// ── 시도명 변환 ──────────────────────────────────────────────────────────────

/// GPS 좌표를 문화정보 API sido 파라미터로 변환
/// 좌표 범위 매핑 방식 (역지오코딩 라이브러리 불필요)
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

// ── 위치 + 전시 목록 상태 ────────────────────────────────────────────────────

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
    double? userLat;
    double? userLng;
    bool hasLocation = false;
    String sido = '서울'; // 기본값: 서울

    // §7: 위치 권한 확인 및 좌표 획득
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.deniedForever &&
          perm != LocationPermission.denied) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, // 전력 절약
            timeLimit: Duration(seconds: 8),
          ),
        );
        // §13: GPS 좌표는 저장하지 않고 sido 변환에만 사용
        userLat = pos.latitude;
        userLng = pos.longitude;
        hasLocation = true;
        sido = latLngToSido(pos.latitude, pos.longitude);
        dev.log('[ExhibitionProvider] sido=$sido', name: 'Exhibition');
      }
    } catch (e) {
      dev.log('[ExhibitionProvider] location error: $e', name: 'Exhibition');
      // 위치 실패 → 서울 기준 날짜순
    }

    // API 호출 (§8: 캐시 포함)
    final result = await ExhibitionApi.instance.fetchExhibitions(sido);

    if (result == null) {
      // API 실패 + 캐시 없음 → 섹션 숨김 (빈 리스트)
      return ExhibitionState(
        items: const [],
        isLoading: false,
        hasLocation: hasLocation,
        userLat: userLat,
        userLng: userLng,
      );
    }

    List<Exhibition> sorted;
    if (hasLocation && userLat != null && userLng != null) {
      // 위치 허용: 거리순 정렬
      final lat = userLat;
      final lng = userLng;
      final withDist = result
          .where((e) => e.latitude != null && e.longitude != null)
          .toList()
        ..sort((a, b) {
          final da = ExhibitionApi.distanceKm(
              lat, lng, a.latitude!, a.longitude!);
          final db = ExhibitionApi.distanceKm(
              lat, lng, b.latitude!, b.longitude!);
          return da.compareTo(db);
        });
      // 좌표 없는 항목은 뒤에 추가
      final withoutDist = result.where((e) => e.latitude == null).toList();
      sorted = [...withDist, ...withoutDist];
    } else {
      // 위치 거부/실패: endDate 임박순 → startDate 빠른 순
      sorted = List.from(result)
        ..sort((a, b) {
          final cmp = a.endDate.compareTo(b.endDate);
          return cmp != 0 ? cmp : a.startDate.compareTo(b.startDate);
        });
    }

    // 최대 10개
    final limited = sorted.take(10).toList();

    return ExhibitionState(
      items: limited,
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
