import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/auth_required_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../domain/models/feedback_item.dart';

final _feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (_) => FeedbackRepository(),
);

/// 내 문의 내역 Provider
final _myFeedbackProvider = FutureProvider.autoDispose<List<FeedbackItem>>(
  (ref) => ref.watch(_feedbackRepositoryProvider).fetchMyFeedback(),
);

/// 문의/건의 화면 (R6: 탭 2개 — 문의하기 + 내 문의 내역)
/// R20: initialTab 파라미터 추가 — 알림 딥링크에서 내역 탭으로 직접 이동
class FeedbackScreen extends ConsumerStatefulWidget {
  final int initialTab; // R20: 0=문의하기, 1=내 문의 내역
  const FeedbackScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab, // R20: 알림 딥링크 지원
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('문의 / 건의'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '문의하기'),
            Tab(text: '내 문의 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SubmitTab(
            onSubmitSuccess: () {
              // 제출 성공 시 내역 탭으로 이동 + 목록 갱신
              _tabController.animateTo(1);
              ref.invalidate(_myFeedbackProvider);
            },
          ),
          const _HistoryTab(),
        ],
      ),
    );
  }
}

// ── 문의하기 탭 ──────────────────────────────────────────────────────────────

class _SubmitTab extends ConsumerStatefulWidget {
  final VoidCallback onSubmitSuccess;
  const _SubmitTab({required this.onSubmitSuccess});

  @override
  ConsumerState<_SubmitTab> createState() => _SubmitTabState();
}

class _SubmitTabState extends ConsumerState<_SubmitTab> {
  FeedbackCategory _selectedCategory = FeedbackCategory.bug;
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _errorText = '내용을 입력해주세요.');
      return;
    }
    if (content.length < 10) {
      setState(() => _errorText = '10자 이상 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(_feedbackRepositoryProvider).submitFeedback(
            category: _selectedCategory,
            content: content,
          );
      if (!mounted) return;
      _contentController.clear();
      setState(() {
        _selectedCategory = FeedbackCategory.bug;
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('소중한 의견 감사합니다! 검토 후 반영하겠습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
      widget.onSubmitSuccess();
    } on AuthRequiredException {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = '로그인이 필요한 기능입니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = '제출에 실패했어요. 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '유형',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackCategory.values.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat.label),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                  ),
                ),
                backgroundColor: AppTheme.surfaceColor,
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            '내용',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            maxLength: 1000,
            maxLines: 8,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '내용을 자세히 입력해주세요 (최소 10자)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
              errorText: _errorText,
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '* 개인정보(이름, 연락처 등)는 포함하지 마세요.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('제출하기'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 내 문의 내역 탭 ──────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeedback = ref.watch(_myFeedbackProvider);

    return asyncFeedback.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '내역을 불러오지 못했어요.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  '제출한 문의가 없어요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _FeedbackHistoryCard(item: item);
          },
        );
      },
    );
  }
}

class _FeedbackHistoryCard extends StatelessWidget {
  final FeedbackItem item;
  const _FeedbackHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasReply = item.adminReply != null && item.adminReply!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 행: 카테고리 뱃지 + 상태 뱃지 + 날짜 ──────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.category.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // R20: 상태 뱃지
              _StatusBadge(status: item.status, hasReply: hasReply),
              const Spacer(),
              Text(
                _formatDate(item.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── 문의 내용 ────────────────────────────────────────────────────
          Text(
            item.content,
            style: const TextStyle(fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          // ── R20: 답변 블록 ───────────────────────────────────────────────
          if (hasReply) ...[
            const SizedBox(height: 12),
            _ReplyBlock(
              reply: item.adminReply!,
              repliedAt: item.repliedAt,
            ),
          ] else ...[
            const SizedBox(height: 10),
            const _PendingBadge(),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

/// R20: 상태 뱃지 (answered / pending / closed)
class _StatusBadge extends StatelessWidget {
  final String status;
  final bool hasReply;
  const _StatusBadge({required this.status, required this.hasReply});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    if (hasReply || status == 'answered') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      label = '답변 완료';
    } else if (status == 'closed') {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      label = '종료';
    } else {
      bgColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFF57F17);
      label = '검토중';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// R20: 답변 대기중 표시
class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded,
            size: 13, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Text(
          '답변 대기중',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

/// R20: 관리자 답변 블록
class _ReplyBlock extends StatelessWidget {
  final String reply;
  final DateTime? repliedAt;
  const _ReplyBlock({required this.reply, this.repliedAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  size: 14, color: Color(0xFF388E3C)),
              const SizedBox(width: 4),
              const Text(
                '뮤즐리 팀 답변',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF388E3C),
                ),
              ),
              if (repliedAt != null) ...[
                const Spacer(),
                Text(
                  _formatDate(repliedAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF66BB6A),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
