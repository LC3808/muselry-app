import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart';
import '../../providers/review_provider.dart';

/// 단일 리뷰 상세 화면 (R5: 알림 딥링크 /reviews/:reviewId)
///
/// R13: 진입 시 댓글 자동 로드 + highlightCommentId 댓글 하이라이트
/// R24: 댓글 입력 UI 추가 (로그인 상태면 어느 경로로 진입해도 활성화)
class ReviewDetailScreen extends ConsumerWidget {
  final String reviewId;
  final String? highlightCommentId; // R13: 알림에서 전달된 댓글 ID

  const ReviewDetailScreen({
    super.key,
    required this.reviewId,
    this.highlightCommentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(_reviewByIdProvider(reviewId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('리뷰'),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                '리뷰를 불러오지 못했어요.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(_reviewByIdProvider(reviewId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (review) {
          if (review == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    '리뷰를 찾을 수 없어요.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            );
          }
          return _ReviewDetailBody(
            review: review,
            highlightCommentId: highlightCommentId,
          );
        },
      ),
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _reviewByIdProvider =
    FutureProvider.autoDispose.family<Review?, String>((ref, reviewId) async {
  final repo = ref.read(reviewRepositoryProvider);
  return repo.fetchReviewById(reviewId);
});

// ── Body ──────────────────────────────────────────────────────────────────────

/// R13: 리뷰 본문 + 댓글 목록 자동 로드 + 하이라이트
/// R24: 댓글 입력 UI 추가
class _ReviewDetailBody extends ConsumerStatefulWidget {
  final Review review;
  final String? highlightCommentId;

  const _ReviewDetailBody({
    required this.review,
    this.highlightCommentId,
  });

  @override
  ConsumerState<_ReviewDetailBody> createState() => _ReviewDetailBodyState();
}

class _ReviewDetailBodyState extends ConsumerState<_ReviewDetailBody> {
  final ScrollController _scrollController = ScrollController();

  // R24: 댓글 입력 컨트롤러
  final TextEditingController _inputController = TextEditingController();
  bool _isSubmitting = false;
  String? _editingCommentId;

  // R13: 댓글 GlobalKey 맵 (하이라이트 스크롤용)
  final Map<String, GlobalKey> _commentKeys = {};

  @override
  void initState() {
    super.initState();
    // R13: 진입 시 댓글 자동 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(commentsForReviewDetailProvider(widget.review.id).notifier)
          .fetch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  /// R13: 하이라이트 댓글로 스크롤
  void _scrollToHighlight(String commentId) {
    final key = _commentKeys[commentId];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  // R24: 댓글 작성/수정 제출
  Future<void> _submitComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || content.length > 500) return;

    setState(() => _isSubmitting = true);
    try {
      if (_editingCommentId != null) {
        await ref
            .read(commentListProvider(widget.review.id).notifier)
            .editComment(commentId: _editingCommentId!, content: content);
        // 편집 완료 후 commentsForReviewDetailProvider도 갱신
        await ref
            .read(commentsForReviewDetailProvider(widget.review.id).notifier)
            .fetch();
        setState(() => _editingCommentId = null);
      } else {
        await ref
            .read(commentListProvider(widget.review.id).notifier)
            .addComment(content: content);
        // 작성 완료 후 commentsForReviewDetailProvider도 갱신
        await ref
            .read(commentsForReviewDetailProvider(widget.review.id).notifier)
            .fetch();
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

  // R24: 댓글 삭제
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
            child: Text('삭제', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(commentListProvider(widget.review.id).notifier)
          .removeComment(commentId);
      // 삭제 후 commentsForReviewDetailProvider도 갱신
      await ref
          .read(commentsForReviewDetailProvider(widget.review.id).notifier)
          .fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsState =
        ref.watch(commentsForReviewDetailProvider(widget.review.id));
    // R24: 로그인 상태 확인 (어느 경로로 진입해도 동일하게 적용)
    final currentUser = ref.watch(currentUserProvider);

    // R13: 댓글 로드 완료 후 하이라이트 댓글로 스크롤
    ref.listen(commentsForReviewDetailProvider(widget.review.id),
        (prev, next) {
      if (next.isLoaded && widget.highlightCommentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlight(widget.highlightCommentId!);
        });
      }
    });

    return Column(
      children: [
        // ── 스크롤 영역 ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 작성자 + 별점 ──────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.dividerColor,
                      backgroundImage: widget.review.authorAvatarUrl != null
                          ? NetworkImage(widget.review.authorAvatarUrl!)
                          : null,
                      child: widget.review.authorAvatarUrl == null
                          ? Icon(Icons.person, size: 20, color: Colors.grey[400])
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.review.authorNickname ?? '익명',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDate(widget.review.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StarRow(rating: widget.review.rating),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.dividerColor),
                const SizedBox(height: 16),

                // ── 리뷰 내용 ──────────────────────────────────────────────
                Text(
                  widget.review.content,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 24),

                // ── 박물관 이동 버튼 ────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/museum/${widget.review.museumId}'),
                  icon: const Icon(Icons.museum_outlined, size: 18),
                  label: Text(
                    widget.review.museum?.name ?? '박물관 보기',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.dividerColor),
                    foregroundColor: AppTheme.textPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── 댓글 섹션 헤더 ──────────────────────────────────────────
                Divider(color: AppTheme.dividerColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      commentsState.isLoading
                          ? '댓글 불러오는 중...'
                          : '댓글 ${commentsState.comments.length}개',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 댓글 목록 ──────────────────────────────────────────────
                if (commentsState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (commentsState.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      commentsState.error!,
                      style: TextStyle(fontSize: 13, color: Colors.red[400]),
                    ),
                  )
                else if (commentsState.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '아직 댓글이 없어요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  )
                else
                  ...commentsState.comments.map((comment) {
                    _commentKeys.putIfAbsent(comment.id, () => GlobalKey());
                    final isHighlighted =
                        comment.id == widget.highlightCommentId;
                    final isMyComment = comment.userId == currentUser?.id;
                    return _CommentItem(
                      key: _commentKeys[comment.id],
                      comment: comment,
                      isHighlighted: isHighlighted,
                      isMyComment: isMyComment,
                      onEdit: isMyComment
                          ? () {
                              setState(() {
                                _editingCommentId = comment.id;
                                _inputController.text = comment.content;
                              });
                            }
                          : null,
                      onDelete:
                          isMyComment ? () => _deleteComment(comment.id) : null,
                    );
                  }),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── R24: 댓글 입력창 (로그인 시만 표시) ─────────────────────────────
        if (currentUser != null)
          _CommentInputBar(
            controller: _inputController,
            isSubmitting: _isSubmitting,
            isEditing: _editingCommentId != null,
            onSubmit: _submitComment,
            onCancelEdit: () {
              setState(() {
                _editingCommentId = null;
                _inputController.clear();
              });
            },
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── R24: 댓글 입력 바 ─────────────────────────────────────────────────────────

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onSubmit;
  final VoidCallback onCancelEdit;

  const _CommentInputBar({
    required this.controller,
    required this.isSubmitting,
    required this.isEditing,
    required this.onSubmit,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        isEditing ? 6 : 8,
        12,
        MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '댓글 수정 중',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancelEdit,
                    child: Text(
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
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: isSubmitting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: onSubmit,
                        icon: Icon(
                          Icons.send_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── R13: 댓글 아이템 ──────────────────────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isHighlighted;
  final bool isMyComment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentItem({
    super.key,
    required this.comment,
    this.isHighlighted = false,
    this.isMyComment = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : AppTheme.dividerColor,
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                backgroundImage: comment.authorAvatarUrl != null
                    ? NetworkImage(comment.authorAvatarUrl!)
                    : null,
                child: comment.authorAvatarUrl == null
                    ? Text(
                        (comment.authorNickname ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.authorNickname ?? '익명',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Text(
                _formatDate(comment.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              // R13: 하이라이트 댓글에 "새 댓글" 뱃지
              if (isHighlighted) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '새 댓글',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              // R24: 내 댓글 수정/삭제 메뉴
              if (isMyComment) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('수정')),
                    const PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
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

// ── R13: 댓글 상태 (단일 리뷰용) ─────────────────────────────────────────────

class _CommentsState {
  final List<Comment> comments;
  final bool isLoading;
  final bool isLoaded;
  final String? error;

  const _CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.isLoaded = false,
    this.error,
  });

  _CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    bool? isLoaded,
    String? error,
  }) {
    return _CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      error: error,
    );
  }
}

class _CommentsNotifier extends FamilyNotifier<_CommentsState, String> {
  @override
  _CommentsState build(String arg) => const _CommentsState();

  Future<void> fetch() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(commentRepositoryProvider);
      final comments = await repo.fetchCommentsForReview(arg);
      state = state.copyWith(
        comments: comments,
        isLoading: false,
        isLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '댓글을 불러오지 못했어요.',
      );
    }
  }
}

/// R13: 단일 리뷰 화면 전용 댓글 provider (commentsForReviewProvider와 분리)
final commentsForReviewDetailProvider = NotifierProvider.family<
    _CommentsNotifier, _CommentsState, String>(
  _CommentsNotifier.new,
);

// ── 별점 위젯 ─────────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && (i < rating);
        return Icon(
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          size: 16,
          color: const Color(0xFFF5A623),
        );
      }),
    );
  }
}
