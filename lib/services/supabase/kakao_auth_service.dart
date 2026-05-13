import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 카카오 로그인 서비스
///
/// 동작 방식:
/// 1. kakao_flutter_sdk_user로 카카오 액세스 토큰 획득
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
  /// 카카오톡 앱이 설치된 경우 앱으로, 미설치 시 카카오 계정(웹)으로 로그인
  Future<AuthResponse> signInWithKakao() async {
    try {
      // 1. 카카오 액세스 토큰 획득
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        debugPrint('[KakaoAuth] 카카오톡 앱으로 로그인 시도');
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        debugPrint('[KakaoAuth] 카카오 계정(웹)으로 로그인 시도');
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      debugPrint('[KakaoAuth] 카카오 액세스 토큰 획득 성공');

      // 2. Supabase에 카카오 토큰으로 로그인
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken ?? '',
        accessToken: token.accessToken,
      );

      debugPrint('[KakaoAuth] Supabase 세션 발급 성공: ${response.user?.id}');
      return response;
    } on KakaoAuthException catch (e) {
      debugPrint('[KakaoAuth] 카카오 인증 오류: ${e.error} - ${e.errorDescription}');
      rethrow;
    } on KakaoClientException catch (e) {
      debugPrint('[KakaoAuth] 카카오 클라이언트 오류: $e');
      rethrow;
    } on AuthException catch (e) {
      debugPrint('[KakaoAuth] Supabase 인증 오류: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[KakaoAuth] 알 수 없는 오류: $e');
      rethrow;
    }
  }

  /// 카카오 로그인 취소 여부 확인
  bool isCancelled(dynamic error) {
    if (error is KakaoAuthException) {
      // accessDenied = 사용자가 카카오 로그인 취소
      return error.error.toString().contains('accessDenied') ||
          error.errorDescription?.contains('cancel') == true;
    }
    return false;
  }
}
