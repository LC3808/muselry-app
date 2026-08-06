
import 'dart:io'; // File
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/museum_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/museum.dart';
import '../../domain/models/profile.dart';
import 'bookmark_provider.dart';
import 'visit_provider.dart';

// ─── Repository Provider ─────────────────────────────────────────────────────
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// ─── Profile Notifier ────────────────────────────────────────────────────────
/// 내 프로필을 관리하는 AsyncNotifier.
///
/// [설계 근거]
/// - build()에서 profiles 테이블을 조회. row가 없으면 null 반환.
/// - 닉네임/아바타 업데이트 시 서버 응답 후 상태 갱신 (낙관적 업데이트 미적용).
///   프로필 편집은 폼 기반 작업이므로 서버 확인 후 반영이 자연스럽다.
class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final repo = ref.read(profileRepositoryProvider);
    return repo.fetchMyProfile();
  }

  /// 닉네임 업데이트
  Future<void> updateNickname(String nickname) async {
    final repo = ref.read(profileRepositoryProvider);
    final updated = await repo.updateNickname(nickname);
    state = AsyncData(updated);
  }

  /// 아바타 이미지 업로드 후 프로필 URL 갱신
  Future<void> uploadAndUpdateAvatar(File imageFile) async {
    final repo = ref.read(profileRepositoryProvider);
    final url = await repo.uploadAvatar(imageFile);
    final updated = await repo.updateAvatarUrl(url);
    state = AsyncData(updated);
  }

  /// v0.5.0: avatar_storage_path 직접 업데이트 (AvatarUploadService에서 호출)
  /// newPath=null 이면 기본 이미지로 리셋
  Future<void> updateAvatarStoragePath(String? newPath) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      newPath == null
          ? current.copyWith(clearAvatarStoragePath: true)
          : current.copyWith(avatarStoragePath: newPath),
    );
  }

  /// 프로필 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(profileRepositoryProvider);
      return repo.fetchMyProfile();
    });
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(() {
  return ProfileNotifier();
});

// ─── 표시용 닉네임 Provider ──────────────────────────────────────────────────
/// 닉네임 우선, 없으면 이메일 앞부분, 그것도 없으면 '사용자' 반환.
final displayNameProvider = Provider<String>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.nickname != null && profile!.nickname!.isNotEmpty) {
    return profile.nickname!;
  }
  final user = Supabase.instance.client.auth.currentUser;
  final email = user?.email;
  if (email != null && email.isNotEmpty) {
    return email.split('@').first;
  }
  return '사용자';
});

// ─── 북마크된 박물관 목록 Provider ──────────────────────────────────────────
/// 북마크 ID 목록으로 Museum 객체를 일괄 조회하는 FutureProvider.
///
/// [설계 근거]
/// - BookmarkRepository.fetchMyBookmarks()는 museum 조인 없이 bookmark row만 반환.
/// - 마이페이지 북마크 섹션에서 박물관명/이미지/지역을 표시하려면 Museum 객체 필요.
/// - bookmarkedIdsProvider(Set of String)를 watch하여 북마크 변경 시 자동 재조회.
/// - 최대 20건만 표시 (마이페이지 프리뷰 목적).
final bookmarkedMuseumsProvider = FutureProvider<List<Museum>>((ref) async {
  final ids = ref.watch(bookmarkedIdsProvider);
  if (ids.isEmpty) return [];

  final repo = MuseumRepository();
  // 최대 20건 프리뷰
  final limitedIds = ids.take(20).toList();
  return repo.fetchMuseumsByIds(limitedIds);
});

// ─── 방문 통계 Provider ──────────────────────────────────────────────────────
/// 방문 기록 기반 통계 데이터 모델.
class VisitStats {
  final int totalCount;              // 총 방문 횟수 (중복 포함)
  final int distinctMuseumCount;     // 방문한 고유 공간 수 (레벨 기준)
  final int thisMonthCount;          // 이번 달 방문 횟수
  final Map<String, int> byType;    // 유형별 방문 수
  final Map<String, int> byRegion;  // 지역별 방문 수

  const VisitStats({
    required this.totalCount,
    required this.distinctMuseumCount,
    required this.thisMonthCount,
    required this.byType,
    required this.byRegion,
  });
}

/// myVisitsProvider에서 파생된 방문 통계 Provider.
///
/// [설계 근거]
/// - DB 집계 쿼리 대신 메모리 파생으로 구현.
///   이유: myVisitsProvider가 이미 전체 방문 기록을 로드하므로
///   추가 API 호출 없이 O(n) 집계 가능.
/// - 향후 방문 기록이 수천 건 이상이 되면 DB 집계로 전환 권장.
final visitStatsProvider = Provider<VisitStats?>((ref) {
  final visits = ref.watch(myVisitsProvider).valueOrNull;
  if (visits == null) return null;

  final byType = <String, int>{};
  final byRegion = <String, int>{};
  final now = DateTime.now();
  int thisMonthCount = 0;

  for (final visit in visits) {
    // 이번 달 방문 횟수
    if (visit.visitedAt.year == now.year && visit.visitedAt.month == now.month) {
      thisMonthCount++;
    }
    if (visit.museum != null) {
      final type = visit.museum!.type;
      byType[type] = (byType[type] ?? 0) + 1;

      final region = visit.museum!.region1;
      if (region.isNotEmpty) {
        byRegion[region] = (byRegion[region] ?? 0) + 1;
      }
    }
  }

  final distinctMuseumCount = visits.map((v) => v.museumId).toSet().length;

  return VisitStats(
    totalCount: visits.length,
    distinctMuseumCount: distinctMuseumCount,
    thisMonthCount: thisMonthCount,
    byType: byType,
    byRegion: byRegion,
  );
});

// ─── 나의 문화 레벨 계산 ──────────────────────────────────────────────────────
/// §3 레벨 기준: 다녀온 공간 수(distinctMuseumCount) 기준 절대 등급 6단계.
/// 레벨 기준 = 다녀온 공간 수 (총 방문 횟수 아님 — 같은 곳 반복 방문으로 레벨 오르지 않음).
class CultureLevel {
  final int level;          // 1~6
  final String title;       // 문화 새싹 등
  final int currentCount;   // 현재 다녀온 공간 수
  final int? nextThreshold; // 다음 레벨 기준 (Lv.6이면 null)
  final String progressLabel; // "다음 레벨까지 N곳" or "최고 레벨이에요"

  const CultureLevel({
    required this.level,
    required this.title,
    required this.currentCount,
    this.nextThreshold,
    required this.progressLabel,
  });

  /// 프로그레스바 비율 (0.0 ~ 1.0)
  double get progressRatio {
    if (nextThreshold == null) return 1.0;
    // 현재 레벨 시작 기준
    final start = _levelStart(level);
    final span = nextThreshold! - start;
    if (span <= 0) return 1.0;
    return ((currentCount - start) / span).clamp(0.0, 1.0);
  }

  static int _levelStart(int level) {
    switch (level) {
      case 1: return 1;
      case 2: return 6;
      case 3: return 11;
      case 4: return 21;
      case 5: return 36;
      case 6: return 61; // M9.1-2: 61~
      default: return 1;
    }
  }
}

/// distinctMuseumCount → CultureLevel 계산 함수.
CultureLevel computeCultureLevel(int distinctCount) {
  if (distinctCount == 0) {
    return const CultureLevel(
      level: 0,
      title: '',
      currentCount: 0,
      nextThreshold: 1,
      progressLabel: '첫 방문을 기록해 보세요',
    );
  }
  if (distinctCount <= 5) {
    return CultureLevel(
      level: 1,
      title: 'Lv.1 문화 새싹',
      currentCount: distinctCount,
      nextThreshold: 6,
      progressLabel: '다음 레벨까지 ${6 - distinctCount}곳',
    );
  }
  if (distinctCount <= 10) {
    return CultureLevel(
      level: 2,
      title: 'Lv.2 문화 산책자',
      currentCount: distinctCount,
      nextThreshold: 11,
      progressLabel: '다음 레벨까지 ${11 - distinctCount}곳',
    );
  }
  if (distinctCount <= 20) {
    return CultureLevel(
      level: 3,
      title: 'Lv.3 문화 탐험가',
      currentCount: distinctCount,
      nextThreshold: 21,
      progressLabel: '다음 레벨까지 ${21 - distinctCount}곳',
    );
  }
  if (distinctCount <= 35) {
    return CultureLevel(
      level: 4,
      title: 'Lv.4 문화 애호가',
      currentCount: distinctCount,
      nextThreshold: 36,
      progressLabel: '다음 레벨까지 ${36 - distinctCount}곳',
    );
  }
  if (distinctCount <= 60) { // M9.1-2: 36~60
    return CultureLevel(
      level: 5,
      title: 'Lv.5 문화 큐레이터',
      currentCount: distinctCount,
      nextThreshold: 61,
      progressLabel: '다음 레벨까지 ${61 - distinctCount}곳',
    );
  }
  return CultureLevel(
    level: 6,
    title: 'Lv.6 문화 마스터',
    currentCount: distinctCount,
    nextThreshold: null,
    progressLabel: '최고 레벨이에요 🎉',
  );
}

/// M9.2-1: 레벨 메타데이터 단일 소스 — 다이얼로그 등 외부 참조용 공개 상수.
/// (level, title, rangeLabel) — rangeLabel은 _levelStart 기반으로 자동 계산.
/// 이 리스트를 수정하면 다이얼로그 표시도 자동 반영됨.
const List<(int, String, String)> cultureLevelMeta = [
  (1, 'Lv.1 문화 새싹',     '1~5곳'),
  (2, 'Lv.2 문화 산책자',   '6~10곳'),
  (3, 'Lv.3 문화 탐험가',   '11~20곳'),
  (4, 'Lv.4 문화 애호가',   '21~35곳'),
  (5, 'Lv.5 문화 큐레이터', '36~60곳'), // M9.1-2 임계값 반영
  (6, 'Lv.6 문화 마스터',   '61곳~'),   // M9.1-2 임계값 반영
];

/// visitStatsProvider에서 파생된 CultureLevel Provider.
final cultureLevelProvider = Provider<CultureLevel>((ref) {
  final stats = ref.watch(visitStatsProvider);
  final distinctCount = stats?.distinctMuseumCount ?? 0;
  return computeCultureLevel(distinctCount);
});
