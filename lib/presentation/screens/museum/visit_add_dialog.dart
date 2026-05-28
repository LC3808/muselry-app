import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/duplicate_visit_exception.dart';
import '../../providers/visit_provider.dart';

class VisitAddDialog extends ConsumerStatefulWidget {
  final String museumId;
  final String museumName;

  const VisitAddDialog({
    super.key,
    required this.museumId,
    required this.museumName,
  });

  @override
  ConsumerState<VisitAddDialog> createState() => _VisitAddDialogState();
}

class _VisitAddDialogState extends ConsumerState<VisitAddDialog> {
  late DateTime _selectedDate;
  final _memoController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // 미래 날짜 차단
      locale: const Locale('ko'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    // async gap 이전에 context 의존 값을 미리 캡처
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final scaffoldMessenger = ScaffoldMessenger.of(rootContext);
    try {
      await ref.read(myVisitsProvider.notifier).addVisit(
        museumId: widget.museumId,
        visitedAt: _selectedDate,
        privateNote: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
      );
      if (!mounted) return;

      final museumId = widget.museumId;
      final museumName = widget.museumName;

      Navigator.pop(context);

      // 부모 Scaffold의 ScaffoldMessenger 사용 (다이얼로그가 닫혀도 유효)
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('방문이 기록되었습니다.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '리뷰 쓰기',
            onPressed: () {
              // 부모 context로 GoRouter navigation (museumName을 query 파라미터로 전달)
              rootContext.push(
                '/museum/$museumId/reviews?name=${Uri.encodeComponent(museumName)}',
              );
            },
          ),
        ),
      );
    } on DuplicateVisitException {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이미 기록된 방문'),
          content: Text(
            '${_formatDate(_selectedDate)}에 이미 ${widget.museumName} 방문 기록이 있어요.\n'
            '다른 날짜를 선택하시거나, 방문 기록 화면에서 확인해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('방문 기록 추가'),
      content: SingleChildScrollView(
        // 키보드가 올라와도 스크롤 가능하도록 감쌈
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            '어느 날 다녀오셨나요?',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatDate(_selectedDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '메모 (선택)',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '어떤 점이 인상 깊었나요?',
              counterText: '',
            ),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
