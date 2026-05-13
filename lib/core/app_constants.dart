class AppConstants {
  // 앱 정보
  static const String appName = '뮤즐리';
  static const String appVersion = '0.1.0';

  // Supabase 테이블명
  static const String tableProfiles = 'profiles';
  static const String tableMuseums = 'museums';
  static const String tableBookmarks = 'bookmarks';
  static const String tableVisits = 'visits';
  static const String tableReviews = 'reviews';
  static const String tableReviewLikes = 'review_likes';
  static const String tableReports = 'reports';
  static const String tableEditSuggestions = 'edit_suggestions';

  // Supabase Storage 버킷
  static const String bucketAvatars = 'avatars';
  static const String bucketReviewImages = 'review-images';
  static const String bucketMuseumImages = 'museum-images';

  // 페이지네이션
  static const int defaultPageSize = 20;

  // 박물관 유형
  static const List<String> museumTypes = [
    '박물관',
    '미술관',
    '기념관',
    '전시관',
    '과학관',
    '역사관',
    '문학관',
    '생태관',
    '기타',
  ];

  // 지역 (시/도)
  static const List<String> regions = [
    '서울',
    '부산',
    '대구',
    '인천',
    '광주',
    '대전',
    '울산',
    '세종',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  // 동반자 유형
  static const List<String> companionTypes = [
    '혼자',
    '가족',
    '친구',
    '연인',
    '단체',
  ];
}
