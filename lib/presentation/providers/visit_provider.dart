import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/visit_repository.dart';
import '../../domain/models/visit.dart';

// ─── Repository Provider ────────────────────────────────────────────────────
final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepository();
});

// ─── MyVisits Notifier ──────────────────────────────────────────────────────
/// 내 방문 기록 전체를 관리하는 AsyncNotifier.
///
/// [낙관적 업데이트 미적용 이유]
/// visits는 날짜·메모를 입력하는 폼 기반 작업이므로
/// 서버 응답 후 화면에 반영하는 것이 자연스럽다.
/// 북마크(토글 즉시 반영)와 다른 패턴임을 의도적으로 선택.
class MyVisitsNotifier extends AsyncNotifier<List<Visit>> {
  @override
  Future<List<Visit>> build() async {
    final repo = ref.read(visitRepositoryProvider);
    return repo.fetchMyVisits();
  }

  /// 방문 기록 추가 (서버 응답 후 상태 갱신)
  /// rating 제거 — v1.10 정책: 별점은 review에만
  Future<void> addVisit({
    required String museumId,
    required DateTime visitedAt,
    String? privateNote,
  }) async {
    final repo = ref.read(visitRepositoryProvider);
    final newVisit = await repo.addVisit(
      museumId: museumId,
      visitedAt: visitedAt,
      privateNote: privateNote,
    );
    final current = state.valueOrNull ?? [];
    // visited_at DESC 정렬 유지: 새 기록을 앞에 삽입 후 재정렬
    final updated = [newVisit, ...current]
      ..sort((a, b) {
        final cmp = b.visitedAt.compareTo(a.visitedAt);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    state = AsyncData(updated);
  }

  /// 방문 기록 삭제
  Future<void> deleteVisit(String visitId) async {
    final repo = ref.read(visitRepositoryProvider);
    await repo.deleteVisit(visitId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((v) => v.id != visitId).toList());
  }

  /// 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(visitRepositoryProvider);
      return repo.fetchMyVisits();
    });
  }
}

final myVisitsProvider =
    AsyncNotifierProvider<MyVisitsNotifier, List<Visit>>(() {
  return MyVisitsNotifier();
});

// ─── visitedMuseumIds Provider (O(1) lookup) ────────────────────────────────
/// 방문한 박물관 ID Set.
///
/// [설계 근거]
/// fetchMyVisits()는 limit 없이 전체 방문 기록을 로드하므로
/// myVisitsProvider에서 derived해도 정확성이 보장된다.
/// 단, 향후 페이지네이션 도입 시 fetchVisitedMuseumIds() 기반
/// FutureProvider로 교체할 것 (ISSUE-011 참조).
final visitedMuseumIdsProvider = Provider<Set<String>>((ref) {
  final visits = ref.watch(myVisitsProvider).valueOrNull ?? [];
  return visits.map((v) => v.museumId).toSet();
});

// ─── visitCount Provider ────────────────────────────────────────────────────
/// 총 방문 횟수 (중복 포함). DB countVisits() 기반 별도 FutureProvider.
///
/// [설계 근거]
/// myVisitsProvider.length로 계산하면 향후 페이지네이션 도입 시
/// 부정확한 값이 노출될 수 있다. DB 집계 함수를 직접 호출하여
/// 항상 정확한 총 횟수를 반환한다.
final visitCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(visitRepositoryProvider);
  return repo.countVisits();
});

// ─── visitsForMuseum Provider ────────────────────────────────────────────────
/// 특정 박물관의 내 방문 기록 (visited_at DESC).
/// 상세 화면 "내 방문 기록" 섹션에서 사용.
final visitsForMuseumProvider =
    FutureProvider.family<List<Visit>, String>((ref, museumId) async {
  // myVisitsProvider가 로드된 경우 메모리에서 필터링 (추가 API 호출 없음)
  final allVisits = ref.watch(myVisitsProvider).valueOrNull;
  if (allVisits != null) {
    return allVisits.where((v) => v.museumId == museumId).toList();
  }
  // myVisitsProvider 미로드 시 직접 조회
  final repo = ref.read(visitRepositoryProvider);
  return repo.fetchVisitsForMuseum(museumId);
});
