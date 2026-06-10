import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/auth_required_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../domain/models/feedback_item.dart';

final _feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (_) => FeedbackRepository(),
);

/// 문의/건의 화면 (M6)
/// - 카테고리: 버그 신고 / 기능 건의 / 데이터 오류 / 기타
/// - 내용 최대 1000자
/// - 마이페이지 설정 시트에서 진입
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
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

    // root context 캡처 (async 후 mounted 체크용)
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(_feedbackRepositoryProvider).submitFeedback(
            category: _selectedCategory,
            content: content,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('소중한 의견 감사합니다! 검토 후 반영하겠습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('문의 / 건의'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 선택
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
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
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

              // 내용 입력
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
                    borderSide: BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
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

              // 제출 버튼
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
        ),
      ),
    );
  }
}
