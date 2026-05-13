import 'dart:io';

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
  final int totalCount;
  final Map<String, int> byType;    // 유형별 방문 수
  final Map<String, int> byRegion;  // 지역별 방문 수

  const VisitStats({
    required this.totalCount,
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

  for (final visit in visits) {
    if (visit.museum != null) {
      final type = visit.museum!.type;
      byType[type] = (byType[type] ?? 0) + 1;

      final region = visit.museum!.region1;
      if (region.isNotEmpty) {
        byRegion[region] = (byRegion[region] ?? 0) + 1;
      }
    }
  }

  return VisitStats(
    totalCount: visits.length,
    byType: byType,
    byRegion: byRegion,
  );
});
