import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _onSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _onPrimaryButton() async {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _onSkip();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.maxHeight < 740 || constraints.maxWidth < 380;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isCompact ? 8 : 20,
              ),
              child: Column(
                children: [
                  // ── 상단 여백 ──────────────────────────────────────────────
                  SizedBox(height: isCompact ? 8 : 20),

                  // ── 아이콘 (텍스트 없는 foreground asset) ─────────────────
                  Image.asset(
                    'assets/branding/adaptive_icon_foreground.png',
                    width: isCompact ? 72 : 96,
                    height: isCompact ? 72 : 96,
                    fit: BoxFit.contain,
                  ),

                  SizedBox(height: isCompact ? 12 : 20),

                  // ── 앱 이름 ────────────────────────────────────────────────
                  Text(
                    '뮤즐리',
                    style: TextStyle(
                      fontSize: isCompact ? 22 : 28,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5D4037),
                    ),
                    maxLines: 1,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '나만의 문화지도',
                    style: TextStyle(
                      fontSize: isCompact ? 13 : 15,
                      color: const Color(0xFF6D4C41),
                    ),
                    maxLines: 1,
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Muselry',
                    style: TextStyle(
                      fontSize: isCompact ? 10 : 11,
                      color: const Color(0xFF6D4C41).withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                  ),

                  SizedBox(height: isCompact ? 16 : 28),

                  // ── 페이지 콘텐츠 (Expanded — 남은 공간 자동 사용) ────────
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: const [
                        _OnboardingPage(
                          title: '전국의 문화공간을\n한눈에',
                          description:
                              '박물관, 미술관, 과학관을\n지도와 검색으로 쉽게 찾아보세요',
                        ),
                        _OnboardingPage(
                          title: '다녀온 곳은 기록하고\n가고 싶은 곳은 북마크하고',
                          description:
                              '방문 기록과 별점, 메모를 남기고\n가고 싶은 곳을 북마크해 정리하세요',
                        ),
                        _OnboardingPage(
                          title: '나만의 문화지도를\n완성하세요',
                          description:
                              '박물관, 미술관, 과학관을\n나만의 문화지도로 기록하세요',
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isCompact ? 8 : 12),

                  // ── 페이지 인디케이터 ──────────────────────────────────────
                  _PageIndicator(currentPage: _currentPage, totalPages: 3),

                  SizedBox(height: isCompact ? 12 : 20),

                  // ── 다음/시작하기 버튼 ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: isCompact ? 48 : 56,
                    child: ElevatedButton(
                      onPressed: _onPrimaryButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4622A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == 2 ? '시작하기' : '다음',
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isCompact ? 8 : 12),

                  // ── 건너뛰기 / 자리 보존 ───────────────────────────────────
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _onSkip,
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 13,
                          color: const Color(0xFF6D4C41).withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    SizedBox(height: isCompact ? 32 : 36),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── 페이지 인디케이터 ─────────────────────────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentPage == index
                ? const Color(0xFFD4622A)
                : const Color(0xFF6D4C41).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── 온보딩 페이지 콘텐츠 ─────────────────────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final String title;
  final String description;

  const _OnboardingPage({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 740;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 제목 (FittedBox로 공간 부족 시 자동 축소)
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D4037),
                height: 1.4,
              ),
            ),
          ),
        ),

        SizedBox(height: isCompact ? 12 : 20),

        // 설명 (maxLines + ellipsis로 overflow 방지)
        Flexible(
          child: Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 13 : 15,
              color: const Color(0xFF6D4C41).withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
