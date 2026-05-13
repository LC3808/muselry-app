import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../visit/visit_history_screen.dart';

/// 기록 탭 화면 — 방문 기록 화면으로 위임합니다.
/// P1-1 픽스: 기록 탭이 빈 화면으로 표시되던 문제 해결.
/// VisitHistoryScreen을 직접 임베드하여 방문 기록 목록을 표시합니다.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const VisitHistoryScreen();
  }
}
