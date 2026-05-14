import 'package:supabase_flutter/supabase_flutter.dart';
import 'kakao_auth_service.dart';

class AuthService {
  final KakaoAuthService _kakaoAuthService = KakaoAuthService();
  final SupabaseClient _client = Supabase.instance.client;

  // 현재 세션
  Session? get currentSession => _client.auth.currentSession;

  // 현재 유저
  User? get currentUser => _client.auth.currentUser;

  // 인증 상태 스트림 (로그인/로그아웃 이벤트 감지)
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── 이메일/비밀번호 회원가입 ──────────────────────────────
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // ── 이메일/비밀번호 로그인 ────────────────────────────────
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── 카카오 로그인 ───────────────────────────────────────────
  Future<AuthResponse> signInWithKakao() async {
    return await _kakaoAuthService.signInWithKakao();
  }

  // ── Google 로그인 (Supabase OAuth) ────────────────────────
  /// Supabase OAuth 방식으로 Google 로그인을 시작합니다.
  /// 브라우저/WebView를 통해 인증 후 딥링크로 복귀합니다.
  /// 반환값: true = OAuth 플로우 시작 성공, false = 실패
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.muselry://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  // ── Apple 로그인 (Supabase OAuth, iOS 전용) ───────────────
  /// Sign in with Apple. iOS 빌드에서만 사용합니다.
  /// Apple Developer 계정에서 Sign in with Apple 서비스 ID 및
  /// 프로비저닝 프로파일 설정이 완료되어야 합니다.
  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.muselry://login-callback',
    );
  }

  // ── 로그아웃 ──────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── 비밀번호 재설정 이메일 발송 ───────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── profiles 자동 생성 (B안 fallback) ────────────────────
  /// OAuth 로그인 후 profiles 테이블에 row가 없으면 upsert 합니다.
  /// A안(DB 트리거)이 실패하거나 누락된 경우를 대비한 이중 방어선입니다.
  Future<void> ensureProfile(User user) async {
    try {
      await _client.from('profiles').upsert(
        {
          'id': user.id,
          'nickname': user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@').first ??
              '사용자',
          'avatar_url': user.userMetadata?['avatar_url'] ??
              user.userMetadata?['picture'],
        },
        onConflict: 'id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      // 프로필 생성 실패는 로그인 자체를 막지 않습니다.
      // 다음 앱 실행 시 재시도됩니다.
    }
  }
}
