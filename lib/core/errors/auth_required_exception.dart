/// 인증이 필요한 작업에서 비로그인 상태일 때 throw되는 예외.
/// Day 7 reviews에서도 재사용.
class AuthRequiredException implements Exception {
  const AuthRequiredException([this.message = '로그인이 필요한 기능입니다.']);

  final String message;

  @override
  String toString() => 'AuthRequiredException: $message';
}
