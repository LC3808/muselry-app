# 뮤즐리 (Muselry)

> 박물관에서 시작해, 문화공간 전체로 확장하는 국민 문화 향유 앱

전국 박물관·미술관을 탐색하고, 방문 기록을 남기고, 리뷰를 공유하는 Flutter 기반 모바일 앱입니다.

---

## 주요 기능

- **탐색 및 검색** — 전국 박물관·미술관 정보 조회, 지역/유형/운영 필터링, 키워드 검색
- **지도 기반 탐색** — 네이버 지도 SDK 연동, 마커 클러스터링, 길찾기 딥링크
- **방문 기록 관리** — 북마크(가고 싶어요), 방문 완료, 별점, 개인 메모
- **커뮤니티** — 공개 리뷰 작성·피드 조회, 신고 기능
- **마이페이지** — 방문 통계(총 방문 횟수 / 고유 박물관 수), 내가 다녀온 박물관 지도
- **인기 박물관** — 베이지안 평균 기반 인기 순위 홈 섹션

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| 앱 프레임워크 | Flutter (Dart) |
| 상태 관리 | Riverpod |
| 백엔드/BaaS | Supabase (PostgreSQL, Auth, Storage, RLS) |
| 지도 | Naver Map SDK |
| 인증 | Supabase Auth (이메일, Kakao, Google, Apple) |

---

## 시작하기

### 사전 요구사항

- Flutter SDK 3.x 이상
- Dart SDK 3.x 이상
- Android Studio / Xcode

### 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성하고 아래 키를 입력합니다.  
`.env` 파일은 `.gitignore`에 포함되어 있으므로 절대 커밋하지 마세요.

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
KAKAO_NATIVE_APP_KEY=your_kakao_native_app_key
NAVER_MAP_CLIENT_ID=your_naver_map_client_id
```

### 빌드 및 실행

```bash
flutter pub get
flutter run
```

---

## 프로젝트 구조

```
lib/
├── config/          # 라우터 설정
├── core/            # 테마, 상수, 에러 처리
├── data/            # Repository 계층
│   └── repositories/
├── domain/          # 도메인 모델
│   └── models/
├── presentation/    # UI 계층
│   ├── providers/   # Riverpod Provider
│   ├── screens/     # 화면
│   └── widgets/     # 공통 위젯
└── services/        # 외부 서비스 (Supabase Auth, Kakao)
```

---

## 라이선스

이 프로젝트는 **All Rights Reserved** 입니다.  
소스 코드의 무단 복제, 배포, 상업적 이용을 금지합니다.

© 2026 Muselry. All rights reserved.
