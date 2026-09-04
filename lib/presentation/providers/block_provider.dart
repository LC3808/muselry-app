import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/block_repository.dart';
import '../../domain/models/profile.dart';
import 'auth_provider.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository();
});

/// 현재 사용자가 차단한 사용자 ID 집합.
/// 로그인 상태가 바뀌면 현재 세션 기준으로 다시 조회한다.
final blockedUserIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  ref.watch(currentUserProvider);
  return ref.read(blockRepositoryProvider).getBlockedUserIds();
});

/// 차단한 사용자 관리 화면에 표시할 프로필 목록.
final blockedUsersProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  ref.watch(currentUserProvider);
  return ref.read(blockRepositoryProvider).getBlockedUsers();
});
