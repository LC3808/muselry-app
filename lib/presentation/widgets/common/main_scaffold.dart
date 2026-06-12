import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// W1 수정: StatefulShellRoute에 맞게 StatefulNavigationShell 사용
// 탭 전환 시 스크롤 위치 유지 및 화면 상태 보존
//
// M1: Android 백키 UX 정상화
// - 루트 탭(홈/탐색/지도/기록/커뮤니티)에서 Android 백키 → 홈 탭이 아니면 홈으로 이동,
//   홈 탭이면 종료 확인 스낵바(2초 내 재입력 시 종료)
// - 하위 화면(상세/리뷰 등)은 go_router가 자동으로 앱바 백버튼 + Android 백키 처리
class MainScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  DateTime? _lastBackPressed;

  Future<bool> _onWillPop() async {
    // 홈 탭(index 0)이 아니면 홈 탭으로 이동
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0, initialLocation: true);
      return false;
    }

    // 홈 탭에서 백키: 2초 내 두 번 누르면 종료
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('한 번 더 누르면 앱이 종료됩니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            // W1 수정: goBranch로 탭 전환 — 스크롤 위치 유지
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: '탐색',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: '지도',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '마이페이지',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: '커뮤니티',
            ),
          ],
        ),
      ),
    );
  }
}
