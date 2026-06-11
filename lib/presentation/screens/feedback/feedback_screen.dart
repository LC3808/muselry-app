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
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          Text(
            item.content,
            style: const TextStyle(fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
