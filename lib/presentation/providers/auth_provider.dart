import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/auth_service.dart';

// ── AuthService 싱글턴 Provider ──────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ── 현재 인증 상태 스트림 Provider ──────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// ── 현재 유저 Provider ───────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});

// ── 로그인 여부 Provider ─────────────────────────────────────
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

// ── Auth 상태 관리 Notifier ──────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  // 회원가입
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
    });
  }

  // 로그인
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
    });
  }

  // 로그아웃
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }

  // 카카오 로그인
  Future<void> signInWithKakao() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithKakao();
    });
  }

  // Google 로그인 (Supabase OAuth)
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final launched = await _authService.signInWithGoogle();
      if (!launched) throw Exception('Google 로그인 창을 열 수 없습니다.');
    });
  }

  // Apple 로그인 (Supabase OAuth, iOS 전용)
  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final launched = await _authService.signInWithApple();
      if (!launched) throw Exception('Apple 로그인 창을 열 수 없습니다.');
    });
  }

  // 에러 초기화
  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
