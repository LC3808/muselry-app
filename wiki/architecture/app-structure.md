# 앱 구조 (app-structure)

> 원본: `lib/` 실제 디렉토리, `README.md`. 충돌 시 `lib/` 코드 우선.

## ⚠️ 이중 구조가 공존한다 (중요)
`lib/`에는 **두 가지 조직 방식이 동시에** 있다:
- **`lib/presentation/`** — 화면 중심(legacy 다수). `screens/`, `providers/`, `widgets/`.
- **`lib/features/`** — 기능 중심(신규). `exhibition/`, `nearby/`, `profile/`, `review/`.

→ 새 기능은 `features/<name>/`(모델·api/repository·provider·widgets 자기완결) 경향.
   기존 화면 로직은 `presentation/`에 남아 있다. 파일 찾을 때 **두 곳 다** 확인할 것.

## 계층 (원본: `lib/`)
```
lib/
├── main.dart              # 초기화: dotenv → Kakao SDK → Naver Map init → Supabase.initialize → authStateChange 리스너(ensureProfile)
├── config/router.dart     # go_router: 하단탭 Shell(home/explore/map/mypage/community) + 상세/리뷰/알림/피드백 라우트
├── core/                  # app_constants, theme, errors, utils, media(url resolver)
├── domain/models/         # 9종: museum, profile, bookmark, visit, review, review_image, comment, feedback_item, app_notification
├── data/repositories/     # 8종: museum, profile, bookmark, visit, review, review_image, comment, feedback
├── presentation/          # screens(auth·home·explore·map·mypage·community·detail·review·visit·records·onboarding·notification·feedback), providers(7), widgets
├── services/supabase/     # auth_service.dart, kakao_auth_service.dart
└── features/              # exhibition, nearby(KTO), profile(avatar_upload), review(image_upload)
```

## 라우팅 (원본: `lib/config/router.dart`, `lib/core/app_constants.dart`)
- `go_router` `Provider<GoRouter>` (`routerProvider`), `GoRouterRefreshStream`으로 auth 변화에 리프레시.
- 하단탭 Shell: home / explore / map / mypage(+map,+bookmarks) / community.
- 최상위 라우트: onboarding, login, signup, museumDetail, visitHistory, museumReviews, myReviews, notifications, feedback, reviewDetail.
- 경로 상수는 `AppRoutes`(app_constants.dart).

## 검증 포인트
- `app_constants.dart`의 `appVersion`은 `0.1.0`으로 **stale** — 실제 버전은 `pubspec.yaml`(1.0.1+45) 기준.
