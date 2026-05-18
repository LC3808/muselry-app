import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';  // PlatformException용
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 카카오 로그인 서비스
///
/// 동작 방식:
/// 1. kakao_flutter_sdk_user로 카카오 액세스 토큰 획득
///    - 카카오톡 앱 우선, 실패 시 카카오 계정(웹)으로 fallback
/// 2. 해당 토큰을 Supabase signInWithIdToken (kakao provider)에 전달
/// 3. Supabase가 카카오 토큰을 검증하고 세션 발급
///
/// 이메일 없는 유저 처리:
/// - 카카오 계정에 이메일이 없거나 동의하지 않은 경우에도 로그인 허용
/// - Supabase 대시보드 > Authentication > Providers > Kakao >
///   "Allow users without an email" 활성화 필요
/// - profiles 테이블의 email 컬럼은 nullable로 설계되어 있음
class KakaoAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 카카오 로그인 실행
  ///
  /// 카카오톡 앱이 설치된 경우 앱으로 우선 시도, 실패 시 카카오 계정(웹)으로 fallback.
  /// 사용자가 명시적으로 취소한 경우엔 fallback 하지 않고 그대로 에러 throw.
  Future<AuthResponse> signInWithKakao() async {
    try {
      final token = await _obtainKakaoToken();
      debugPrint('[KakaoAuth] 카카오 액세스 토큰 획득 성공');

      // Supabase에 카카오 토큰으로 로그인
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken ?? '',
        accessToken: token.accessToken,
      );

      debugPrint('[KakaoAuth] Supabase 세션 발급 성공: ${response.user?.id}');
      return response;
    } on AuthException catch (e) {
      debugPrint('[KakaoAuth] Supabase 인증 오류: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[KakaoAuth] 카카오 로그인 실패: $e');
      rethrow;
    }
  }

  /// 카카오 토큰 획득 — 카카오톡 앱 우선, 실패 시 카카오 계정 fallback
  Future<OAuthToken> _obtainKakaoToken() async {
    // 카카오톡 미설치 → 바로 카카오 계정 로그인
    if (!await isKakaoTalkInstalled()) {
      debugPrint('[KakaoAuth] 카카오톡 미설치 → 카카오 계정(웹) 로그인');
      return UserApi.instance.loginWithKakaoAccount();
    }

    // 카카오톡 설치됨 → 앱 로그인 먼저 시도
    debugPrint('[KakaoAuth] 카카오톡 앱으로 로그인 시도');
    try {
      return await UserApi.instance.loginWithKakaoTalk();
    } catch (e) {
      // 사용자가 직접 취소한 경우는 fallback 하지 않고 그대로 throw
      if (_isUserCancelled(e)) {
        debugPrint('[KakaoAuth] 사용자가 카카오톡 로그인 취소');
        rethrow;
      }

      // 그 외 모든 실패(NotSupportError, 계정 미연결, 앱 오류 등) → 카카오 계정으로 fallback
      debugPrint('[KakaoAuth] 카카오톡 앱 로그인 실패 → 카카오 계정(웹) 로그인으로 fallback: $e');
      return UserApi.instance.loginWithKakaoAccount();
    }
  }

  /// 사용자가 명시적으로 취소한 경우 판별
  bool _isUserCancelled(dynamic error) {
    if (error is PlatformException) {
      // 카카오 SDK에서 사용자 취소 시 'CANCELED' 또는 message에 'cancel' 포함
      final code = error.code.toUpperCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('CANCEL') || message.contains('cancel')) {
        return true;
      }
    }
    if (error is KakaoAuthException) {
      // accessDenied = 사용자가 카카오 인증 동의 거부
      return error.error.toString().contains('accessDenied') ||
          (error.errorDescription?.contains('cancel') ?? false);
    }
    return false;
  }

  /// (외부에서 호출 가능한) 카카오 로그인 취소 여부 확인 - 기존 인터페이스 유지
  bool isCancelled(dynamic error) => _isUserCancelled(error);
}