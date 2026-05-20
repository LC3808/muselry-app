import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/auth_service.dart';

// ── AuthService 싱글턴 Provider ──────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ── 현재 인증 상태 스트림 Provider ──────────────────────────
// AuthRetryableFetchException, SocketException 등 세션 복구 실패 시
// 세션을 초기화하여 로그인 화면으로 안전하게 이동합니다.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final client = Supabase.instance.client;

  // 스트림 에러를 catch하여 세션 복구 실패를 안전하게 처리
  final controller = StreamController<AuthState>();

  final subscription = authService.authStateChanges.listen(
    (state) {
      if (!controller.isClosed) controller.add(state);
    },
    onError: (Object error, StackTrace stack) {
      debugPrint('[Auth] authStateChanges error: $error');

      // 네트워크/세션 만료 오류 → 세션 초기화 후 로그인 화면으로
      if (_isSessionRecoveryError(error)) {
        debugPrint('[Auth] session recovery failed — signing out silently');
        // signOut은 비동기지만 스트림 에러 핸들러에서 await 불가
        // unawaited로 실행하고 authStateChanges가 signedOut 이벤트를 emit하면
        // routerProvider가 /login으로 리다이렉트합니다.
        unawaited(
          client.auth.signOut().catchError((e) {
            debugPrint('[Auth] signOut after recovery failure: $e');
          }),
        );
      } else {
        // 그 외 오류는 스트림으로 전달 (Riverpod error state)
        if (!controller.isClosed) controller.addError(error, stack);
      }
    },
    cancelOnError: false, // 에러 발생 시에도 스트림 유지
  );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 세션 복구 실패 여부 판단
bool _isSessionRecoveryError(Object error) {
  if (error is SocketException) return true;
  if (error is AuthRetryableFetchException) return true;
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('expired') ||
        msg.contains('refresh') ||
        msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('fetch')) {
      return true;
    }
  }
  // "Access token is expired and refreshing failed" 패턴
  final errorStr = error.toString().toLowerCase();
  if (errorStr.contains('access token is expired') ||
      errorStr.contains('refreshing failed') ||
      errorStr.contains('failed host lookup') ||
      errorStr.contains('authretryablefetchexception')) {
    return true;
  }
  return false;
}

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
