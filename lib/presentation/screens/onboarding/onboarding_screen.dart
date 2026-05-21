import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/router.dart';

// ─── 브랜드 컬러 (T4 확정) ────────────────────────────────────────────────────
const Color _kBgColor = Color(0xFFFAF7F2);        // Warm Off-White
const Color _kBrownPrimary = Color(0xFF5D4037);   // Deep Museum Brown
const Color _kBrownSub = Color(0xFF6D4C41);       // Brown Variant
const Color _kOrangeAccent = Color(0xFFD4622A);   // Visited Orange (버튼/포인트)
const Color _kCreamBeige = Color(0xFFFBE9D0);     // Cream Beige (아이콘 배경)

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.map_outlined,
      title: '전국의 문화공간을\n한눈에',
      description: '박물관, 미술관, 과학관을\n지도와 검색으로 쉽게 찾아보세요.',
    ),
    _OnboardingPage(
      icon: Icons.bookmark_border_rounded,
      title: '다녀온 곳은 기록하고\n가고 싶은 곳은 북마크하고',
      description: '방문 기록과 별점, 메모를 남기고\n가고 싶은 곳을 북마크로 저장하세요.',
    ),
    _OnboardingPage(
      icon: Icons.place_outlined,
      title: '나만의 문화지도를\n완성하세요',
      description: '박물관, 미술관, 과학관을\n나만의 문화지도로 기록하세요.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 로고 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kCreamBeige,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: _kOrangeAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '뮤즐리',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kBrownPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Muselry',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _kBrownSub,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // 페이지 뷰
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(page: _pages[index]);
                },
              ),
            ),

            // 하단 컨트롤 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Column(
                children: [
                  // 페이지 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _kOrangeAccent
                              : _kBrownSub.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 다음/시작 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrangeAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 건너뛰기 버튼
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: _kBrownSub.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // 아이콘 컨테이너
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _kCreamBeige,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              page.icon,
              size: 48,
              color: _kOrangeAccent,
            ),
          ),
          const SizedBox(height: 40),
          // 제목
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kBrownPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // 설명
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kBrownSub,
              fontSize: 15,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
