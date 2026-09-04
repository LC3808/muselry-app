import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/signup_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/explore/explore_screen.dart';
import '../presentation/screens/map/map_screen.dart';
// M7-A: records_screen removed from shell — import deleted
import '../presentation/screens/community/community_screen.dart';
import '../presentation/screens/detail/museum_detail_screen.dart';
import '../presentation/screens/mypage/bookmarks_screen.dart';
import '../presentation/screens/mypage/mypage_map_screen.dart';
import '../presentation/screens/mypage/mypage_screen.dart';
import '../presentation/screens/mypage/blocked_users_screen.dart';
import '../presentation/screens/visit/visit_history_screen.dart';
import '../presentation/screens/review/review_screen.dart';
import '../presentation/screens/review/my_reviews_screen.dart';
import '../presentation/screens/notification/notification_screen.dart';
import '../presentation/screens/review/review_detail_screen.dart';
import '../presentation/screens/feedback/feedback_screen.dart';
import '../presentation/widgets/common/main_scaffold.dart';

// 라우트 경로 상수
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/';
  static const String explore = '/explore';
  static const String map = '/map';
  static const String records = '/records';
  static const String community = '/community';
  static const String museumDetail = '/museum/:id';
  static const String mypage = '/mypage';
  static const String visitHistory = '/visits';
  static const String museumReviews = '/museum/:id/reviews';
  static const String myReviews = '/my-reviews';
  static const String blockedUsers = '/blocked-users';
  static const String mypageMap = '/mypage/map';
  static const String bookmarks = '/mypage/bookmarks';
  static const String notifications = '/notifications';
  static const String feedback = '/feedback';
  static const String reviewDetail = '/reviews/:reviewId';
}

final routerProvider = Provider<GoRouter>((ref) {
  // authStateProvider를 watch하여 인증 상태 변경 시 라우터가 재생성됨
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    // 인증 상태 변경 시 라우팅 재평가
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authServiceProvider).authStateChanges,
    ),
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final location = state.uri.toString();

      // 인증 화면 경로 여부
      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.onboarding;

      String? finalDestination;

      // 로그인된 상태에서 인증 화면 접근 시 홈으로 리다이렉트
      if (isAuthenticated && isAuthRoute) {
        finalDestination = AppRoutes.home;
      }
      // 비로그인 상태에서 보호된 화면 접근 시 로그인으로 리다이렉트
      else if (!isAuthenticated && !isAuthRoute) {
        finalDestination = AppRoutes.login;
      }

      return finalDestination;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      // W1 수정: ShellRoute → StatefulShellRoute로 마이그레이션
      // 탭 전환 시 스크롤 위치 유지 및 화면 상태 보존
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.mypage,
                builder: (context, state) => const MypageScreen(),
                routes: [
                  GoRoute(
                    path: 'map',
                    builder: (context, state) => const MypageMapScreen(),
                  ),
                  GoRoute(
                    path: 'bookmarks',
                    builder: (context, state) => const BookmarksScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.community,
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.museumDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MuseumDetailScreen(museumId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.visitHistory,
        builder: (context, state) => const VisitHistoryScreen(),
      ),
      // e36819c 원위치 복원 (3481910/c69ced3 실험 제거)
      GoRoute(
        path: AppRoutes.museumReviews,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? '박물관';
          return ReviewScreen(museumId: id, museumName: name);
        },
      ),
      GoRoute(
        path: AppRoutes.myReviews,
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.blockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        // R20: tab 쿼리파라미터 지원 — '1'이면 '내 문의 내역' 탭으로 직접 이동
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final initialTab = tabParam == '1' ? 1 : 0;
          return FeedbackScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: AppRoutes.reviewDetail,
        builder: (context, state) {
          final reviewId = state.pathParameters['reviewId']!;
          // R13: 알림 딥링크에서 commentId 쿼리파라미터 전달
          final commentId = state.uri.queryParameters['commentId'];
          return ReviewDetailScreen(
            reviewId: reviewId,
            highlightCommentId: commentId,
          );
        },
      ),
    ],
  );
});

// GoRouter 리프레시를 위한 스트림 리스너
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
