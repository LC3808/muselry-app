# 개요 (overview)

**Muselry (뮤즐리)** — "전국 박물관·미술관 방문 기록 커뮤니티 앱".
박물관에서 시작해 문화공간 전체로 확장하는 국민 문화 향유 앱.
(원본: `README.md`, `muselry_specification_v1.9.md`)

## 핵심 기능 (원본: README.md)
- 탐색/검색: 전국 박물관·미술관 조회, 지역/유형/운영 필터, 키워드 검색
- 지도 탐색: Naver Map SDK, 마커 클러스터링, 길찾기 딥링크
- 방문 기록: 북마크(가고싶어요), 방문 완료, 별점, 개인 메모
- 커뮤니티: 공개 리뷰 작성·피드·신고
- 마이페이지: 방문 통계, 내가 다녀온 박물관 지도
- 인기 박물관: 베이지안 평균 기반 순위
- 확장: 문화행사(전시) 조회, KTO "함께 가볼 만한 곳"

## 기술 스택 (원본: `pubspec.yaml`)
| 분류 | 기술 |
|------|------|
| 프레임워크 | Flutter / Dart (SDK 3.x) |
| 상태관리 | Riverpod (`flutter_riverpod` 2.6, `riverpod_annotation`) |
| 라우팅 | `go_router` 14.6 |
| 백엔드 | Supabase (`supabase_flutter` 2.8 — PostgreSQL, Auth, Storage, RLS) |
| 지도 | `flutter_naver_map` 1.3, `geolocator` |
| 인증 | Supabase Auth (이메일, Kakao, Google, Apple / `sign_in_with_apple` 7) |
| 코드생성 | `freezed_annotation`, `json_annotation` |
| 외부 API | KTO 관광정보, 한국문화정보원 문화행사 OpenAPI |

## 플랫폼
- Android: `com.muselry.muselry` — compileSdk 36, minSdk 23, targetSdk 36
- iOS: `com.muselry.muselry` — Deployment Target 13.0 (→15.0 예정)

## 상세는
- 구조: [architecture/app-structure.md](architecture/app-structure.md)
- 백엔드: [architecture/backend-supabase.md](architecture/backend-supabase.md)
- 연동: [architecture/integrations.md](architecture/integrations.md)
