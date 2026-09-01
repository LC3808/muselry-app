# 외부 연동 (integrations)

> 원본: `lib/main.dart`, `lib/services/`, `lib/features/`, `supabase/functions/`, `.env.example`.
> 키/시크릿 값은 여기 저장하지 않는다. `.env`(gitignore) 참조.

## 지도 — Naver Map
- `flutter_naver_map` ^1.3.0. `main.dart`에서 `FlutterNaverMap().init(clientId, onAuthFailed)`.
- 위치: `geolocator` ^13.0.2.

## 인증 — Supabase Auth
- 이메일, **Kakao**(`kakao_flutter_sdk_user` 1.9.7+3 — 3.32 호환 위해 핀 고정), **Google**, **Apple**(`sign_in_with_apple` ^7.0.1, iOS 네이티브 `signInWithIdToken`).
- `services/supabase/auth_service.dart`, `kakao_auth_service.dart`.

## KTO 관광정보 OpenAPI — "함께 가볼 만한 곳"
- Flutter → Edge Function `kto-nearby-places` → KTO `KorService2/locationBasedList2`.
- 정책: contentTypeId 화이트리스트 [12,14,25,28], numOfRows=100 → 서버 필터 → 거리순 상위 limit(기본5).
- 서비스키 `KTO_SERVICE_KEY`(Secret)는 앱/응답/로그 미노출. upstream 장애는 200+items:[]로 격리.
- 클라이언트: `lib/features/nearby/` (kto_nearby_repository, nearby_provider, nearby_places_section).

## 문화행사(전시) OpenAPI — 한국문화정보원
- `lib/features/exhibition/` (exhibition_api, exhibition_model, exhibition_provider). XML 파싱(`xml`), `http`, `html_unescape`.

## 이미지
- 프로필/리뷰 사진: `image_picker` + `image_cropper` + `flutter_image_compress`, 업로드는 `features/profile/services/avatar_upload_service.dart`, `features/review/services/review_image_upload_service.dart`.

## 환경변수 (원본: `.env.example`)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `KAKAO_NATIVE_APP_KEY`, `NAVER_MAP_CLIENT_ID`.
