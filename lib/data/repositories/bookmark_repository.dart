import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/bookmark.dart';

class BookmarkRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 내 북마크 전체 조회
  Future<List<Bookmark>> fetchMyBookmarks() async {
    final uid = _userId;
    if (uid == null) return [];

    final response = await _client
        .from('bookmarks')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Bookmark.fromJson(e)).toList();
  }

  /// 북마크 추가
  Future<Bookmark> addBookmark(String museumId) async {
    final uid = _userId;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final response = await _client
        .from('bookmarks')
        .insert({'user_id': uid, 'museum_id': museumId})
        .select()
        .single();

    return Bookmark.fromJson(response);
  }

  /// 북마크 삭제
  Future<void> removeBookmark(String museumId) async {
    final uid = _userId;
    if (uid == null) throw Exception('로그인이 필요합니다');

    await _client
        .from('bookmarks')
        .delete()
        .eq('user_id', uid)
        .eq('museum_id', museumId);
  }

  /// 특정 박물관 북마크 여부 확인
  Future<bool> isBookmarked(String museumId) async {
    final uid = _userId;
    if (uid == null) return false;

    final response = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', uid)
        .eq('museum_id', museumId)
        .maybeSingle();

    return response != null;
  }
}
