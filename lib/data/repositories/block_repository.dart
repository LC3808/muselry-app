import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/auth_required_exception.dart';
import '../../domain/models/profile.dart';

/// 사용자 차단 관계를 관리하는 Repository.
///
/// 차단은 현재 사용자 화면에서만 상대 사용자의 공개 리뷰를 숨긴다.
/// 상대 계정, 리뷰 데이터, 신고 및 모더레이션 상태는 변경하지 않는다.
class BlockRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  String get _requireUserId {
    final userId = _userId;
    if (userId == null) throw const AuthRequiredException();
    return userId;
  }

  /// 현재 사용자가 [blockedUserId]를 차단한다.
  Future<void> blockUser(String blockedUserId) async {
    final blockerId = _requireUserId;
    if (blockerId == blockedUserId) {
      throw ArgumentError('자기 자신은 차단할 수 없습니다.');
    }

    await _client.from('user_blocks').insert({
      'blocker_id': blockerId,
      'blocked_id': blockedUserId,
    });
  }

  /// 현재 사용자가 [blockedUserId] 차단을 해제한다.
  Future<void> unblockUser(String blockedUserId) async {
    final blockerId = _requireUserId;
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedUserId);
  }

  /// 현재 사용자가 차단한 사용자 ID 집합을 조회한다.
  Future<Set<String>> getBlockedUserIds() async {
    final blockerId = _userId;
    if (blockerId == null) return <String>{};

    final response = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', blockerId);

    return (response as List).map((row) => row['blocked_id'] as String).toSet();
  }

  /// 현재 사용자가 차단한 사용자 프로필을 차단한 순서대로 조회한다.
  Future<List<Profile>> getBlockedUsers() async {
    final blockerId = _userId;
    if (blockerId == null) return <Profile>[];

    final blockRows = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', blockerId)
        .order('created_at', ascending: false);

    final blockedIds = (blockRows as List)
        .map((row) => row['blocked_id'] as String)
        .toList();
    if (blockedIds.isEmpty) return <Profile>[];

    final profileRows = await _client
        .from('profiles')
        .select('id, nickname, avatar_url, avatar_storage_path, updated_at')
        .inFilter('id', blockedIds);

    final profilesById = <String, Profile>{
      for (final row in profileRows as List)
        (row['id'] as String): Profile.fromJson(row),
    };

    return blockedIds
        .map((id) => profilesById[id])
        .whereType<Profile>()
        .toList();
  }
}
