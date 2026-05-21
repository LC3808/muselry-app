import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/router.dart';

// ─── 브랜드 컬러 (T4 확정) ────────────────────────────────────────────────────
const Color _kBgColor = Color(0xFFFAF7F2);        // Warm Off-White
const Color _kBrownPrimary = Color(0xFF5D4037);   // Deep Museum Brown
const Color _kBrownSub = Color(0xFF6D4C41);       // Brown Variant
const Color _kOrangeAccent = Color(0xFFD4622A);   // Visited Orange (버튼/포인트)

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
            // ── 상단 브랜드 영역 (로고 이미지 + 뮤즐리 타이틀 + 서브) ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
              child: Column(
                children: [
                  // 로고 이미지
                  Image.asset(
                    'assets/branding/splash_logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  // 메인 타이틀: 뮤즐리
                  const Text(
                    '뮤즐리',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _kBrownPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 서브 타이틀: 나만의 문화지도
                  Text(
                    '나만의 문화지도',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _kBrownSub.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 부제: Muselry (작게)
                  Text(
                    'Muselry',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: _kBrownSub.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── 페이지 뷰 ─────────────────────────────────────────────────────
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

            // ── 하단 컨트롤 영역 ──────────────────────────────────────────────
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
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 메인 문구 (페이지 제목)
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kBrownPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // 설명 문구
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kBrownSub.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.7,
            ),
          ),
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
