import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/auth_required_exception.dart';
import '../../domain/models/feedback_item.dart';

/// 문의/건의 저장소.
/// - feedback 테이블에 INSERT (RLS: 본인 row만 작성 가능)
/// - 중복 제한 없음 (여러 번 제출 가능)
class FeedbackRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String get _requireUserId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthRequiredException();
    return uid;
  }

  /// 문의/건의 제출
  Future<FeedbackItem> submitFeedback({
    required FeedbackCategory category,
    required String content,
  }) async {
    final uid = _requireUserId;

    final response = await _client
        .from('feedback')
        .insert({
          'user_id': uid,
          'category': category.toJson(),
          'content': content.trim(),
        })
        .select()
        .single();
    return FeedbackItem.fromJson(response);
  }
}
