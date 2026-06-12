// §8-1: 닉네임 마스킹 공통 유틸 함수
// 적용 화면: 커뮤니티 피드(리뷰·댓글) / 시설 리뷰 목록 / 단일 리뷰 화면(리뷰 작성자·댓글 작성자)
// 본인 화면(마이페이지 프로필, 내가 쓴 리뷰의 내 이름)은 마스킹 제외

/// 닉네임 마스킹: 앞 2글자 + ****** (2~6개)
/// - null/empty → '익명'
/// - 이메일 형식 → 로컬파트 앞 2글자 + ******
/// - 2글자 이하 → 그대로 반환
/// - 3글자 이상 → 앞 2글자 + '*' * (length-2).clamp(2,6)
String maskNickname(String? nickname) {
  if (nickname == null || nickname.isEmpty) return '익명';
  if (nickname.contains('@')) {
    final parts = nickname.split('@');
    final local = parts[0];
    if (local.length <= 2) return '$local@***';
    return '${local.substring(0, 2)}${'*' * (local.length - 2).clamp(2, 6)}';
  }
  if (nickname.length <= 2) return nickname;
  return '${nickname.substring(0, 2)}${'*' * (nickname.length - 2).clamp(2, 6)}';
}
