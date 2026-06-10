import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart';
import '../../providers/review_provider.dart';

/// 커뮤니티 화면 (M5 업데이트)
/// - 최신 리뷰 피드 + 댓글 CRUD
/// - 알림 뱃지 (빨간 점) + 알림 목록 진입
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(communityReviewsProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityReviewsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final unreadAsync = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('커뮤니티'),
        centerTitle: false,
        actions: [
          // M5: 알림 버튼 + 빨간 점 뱃지
          if (currentUser != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: '알림',
                  onPressed: () => context.push(AppRoutes.notifications),
                ),
                unreadAsync.whenOrNull(
                  data: (count) => count > 0
                      ? Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE74C3C),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ) ?? const SizedBox.shrink(),
              ],
            ),
        ],
      ),
      body: _buildBody(state, currentUser?.id),
    );
  }

  Widget _buildBody(CommunityReviewsState state, String? currentUserId) {
    if (state.isLoading && state.reviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('리뷰를 불러오지 못했어요.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(communityReviewsProvider.notifier).fetchInitial(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (state.reviews.isEmpty) {
      return _EmptyFeed();
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(communityReviewsProvider.notifier).fetchInitial(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: state.reviews.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == state.reviews.length) {
            return const _FeedFooter();
          }
          return _ReviewFeedCard(
            review: state.reviews[index],
            currentUserId: currentUserId,
            onMuseumTap: (museumId) => context.push(
              AppRoutes.museumDetail.replaceFirst(':id', museumId),
            ),
          );
        },
      ),
    );
  }
}

// ─── 리뷰 피드 카드 (M5: 댓글 섹션 추가) ─────────────────────────────────────

class _ReviewFeedCard extends ConsumerStatefulWidget {
  final Review review;
  final String? currentUserId;
  final void Function(String museumId) onMuseumTap;

  const _ReviewFeedCard({
    required this.review,
    required this.currentUserId,
    required this.onMuseumTap,
  });

  @override
  ConsumerState<_ReviewFeedCard> createState() => _ReviewFeedCardState();
}

class _ReviewFeedCardState extends ConsumerState<_ReviewFeedCard> {
  bool _showComments = false;
  bool _commentsLoaded = false;

  void _toggleComments() {
    setState(() => _showComments = !_showComments);
    if (!_commentsLoaded) {
      _commentsLoaded = true;
      ref
          .read(commentListProvider.notifier)
          .fetchComments(widget.review.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 박물관 정보 헤더
          if (widget.review.museum != null)
            InkWell(
              onTap: () => widget.onMuseumTap(widget.review.museumId),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Text('🏛️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.review.museum!.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      widget.review.museum!.region1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ],
                ),
              ),
            ),

          // 리뷰 본문
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      backgroundImage: widget.review.authorAvatarUrl != null
                          ? NetworkImage(widget.review.authorAvatarUrl!)
                          : null,
                      child: widget.review.authorAvatarUrl == null
                          ? Text(
                              (widget.review.authorNickname ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _maskNickname(widget.review.authorNickname),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          Text(
                            _formatDate(widget.review.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StarRating(rating: widget.review.rating),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.review.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // M5: 댓글 토글 버튼
          InkWell(
            onTap: widget.currentUserId != null ? _toggleComments : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _showComments
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showComments ? '댓글 접기' : '댓글 보기',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // M5: 댓글 섹션
          if (_showComments)
            _CommentSection(
              reviewId: widget.review.id,
              currentUserId: widget.currentUserId,
            ),
        ],
      ),
    );
  }

  static String _maskNickname(String? nickname) {
    if (nickname == null || nickname.isEmpty) return '익명';
    if (nickname.contains('@')) {
      final parts = nickname.split('@');
      final local = parts[0];
      final domain = parts.length > 1 ? '@${parts[1]}' : '';
      if (local.length <= 2) return '$local****$domain';
      return '${local.substring(0, 2)}****$domain';
    }
    if (nickname.length <= 2) return nickname;
    return '${nickname.substring(0, 2)}${'*' * (nickname.length - 2).clamp(2, 6)}';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── M5: 댓글 섹션 ────────────────────────────────────────────────────────────

class _CommentSection extends ConsumerStatefulWidget {
  final String reviewId;
  final String? currentUserId;

  const _CommentSection({
    required this.reviewId,
    required this.currentUserId,
  });

  @override
  ConsumerState<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<_CommentSection> {
  final _inputController = TextEditingController();
  bool _isSubmitting = false;
  String? _editingCommentId;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || content.length > 500) return;

    setState(() => _isSubmitting = true);
    try {
      if (_editingCommentId != null) {
        await ref.read(commentListProvider.notifier).editComment(
              commentId: _editingCommentId!,
              content: content,
            );
        _editingCommentId = null;
      } else {
        await ref.read(commentListProvider.notifier).addComment(
              reviewId: widget.reviewId,
              content: content,
            );
      }
      _inputController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 작성에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startEdit(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _inputController.text = comment.content;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _inputController.clear();
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('댓글을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(commentListProvider.notifier).removeComment(commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentListProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),

          // 댓글 목록
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (state.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '첫 번째 댓글을 남겨보세요',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            )
          else
            ...state.comments.map((comment) => _CommentItem(
                  comment: comment,
                  isMyComment: comment.userId == widget.currentUserId,
                  onEdit: () => _startEdit(comment),
                  onDelete: () => _deleteComment(comment.id),
                )),

          // 댓글 입력창 (로그인 시만)
          if (widget.currentUserId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editingCommentId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '댓글 수정 중',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _cancelEdit,
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          maxLength: 500,
                          maxLines: null,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: '댓글을 입력하세요 (최대 500자)',
                            hintStyle: const TextStyle(fontSize: 13),
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.dividerColor),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ||
                                  _inputController.text.trim().isEmpty
                              ? null
                              : _submitComment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _editingCommentId != null ? '수정' : '등록',
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 댓글 아이템 ──────────────────────────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isMyComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.comment,
    required this.isMyComment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Text(
                    (comment.authorNickname ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _maskNickname(comment.authorNickname),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (isMyComment) ...[
                      GestureDetector(
                        onTap: onEdit,
                        child: const Text(
                          '수정',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _maskNickname(String? nickname) {
    if (nickname == null || nickname.isEmpty) return '익명';
    if (nickname.contains('@')) {
      final parts = nickname.split('@');
      final local = parts[0];
      final domain = parts.length > 1 ? '@${parts[1]}' : '';
      if (local.length <= 2) return '$local****$domain';
      return '${local.substring(0, 2)}****$domain';
    }
    if (nickname.length <= 2) return nickname;
    return '${nickname.substring(0, 2)}${'*' * (nickname.length - 2).clamp(2, 6)}';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── 별점 위젯 ────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A623)),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF5A623),
          ),
        ),
      ],
    );
  }
}

// ─── 빈 피드 ─────────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            '아직 작성된 리뷰가 없어요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '박물관을 방문하고 첫 번째 리뷰를 남겨보세요!',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 피드 하단 ────────────────────────────────────────────────────────────────

class _FeedFooter extends StatelessWidget {
  const _FeedFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
