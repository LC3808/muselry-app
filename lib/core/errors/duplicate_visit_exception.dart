/// 같은 날 같은 박물관 중복 방문 추가 시 발생.
class DuplicateVisitException implements Exception {
  const DuplicateVisitException();
  @override
  String toString() => 'DuplicateVisitException: 같은 날 같은 박물관 방문 기록이 이미 존재합니다.';
}
