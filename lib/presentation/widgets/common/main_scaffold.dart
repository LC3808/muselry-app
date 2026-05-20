import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// W1 수정: StatefulShellRoute에 맞게 StatefulNavigationShell 사용
// 탭 전환 시 스크롤 위치 유지 및 화면 상태 보존
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // [진단] 하단 탭 onTap 로그
          // ignore: avoid_print
          print('[BottomNav] tapped index=$index currentIndex=${navigationShell.currentIndex}');

          // W1 수정: goBranch로 탭 전환 — 스크롤 위치 유지
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );

          // [진단] goBranch 호출 후 로그
          // ignore: avoid_print
          print('[BottomNav] goBranch($index) called');
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
            icon: Icon(Icons.bookmark_border_outlined),
            activeIcon: Icon(Icons.bookmark),
            label: '기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '커뮤니티',
          ),
        ],
      ),
    );
  }
}
