# 상태 관리 & 라우팅 (state-management)

> 원본: `pubspec.yaml`, `lib/presentation/providers/`, `lib/features/**/*_provider.dart`, `lib/config/router.dart`.

## Riverpod
- `flutter_riverpod` ^2.6.1 + `riverpod_annotation` ^2.6.1.
- 앱 루트는 `ProviderScope`(main.dart). 
- Provider 위치가 **두 곳**:
  - `lib/presentation/providers/` — auth, bookmark, comment, museum, profile, review, visit.
  - `lib/features/<name>/<name>_provider.dart` — nearby, exhibition 등.

## 인증 상태
- `main.dart`에서 `Supabase.instance.client.auth.onAuthStateChange` 구독 → signedIn 시 `AuthService.ensureProfile()`.
- 소셜(Google/Apple) OAuth는 딥링크 콜백 → authStateChanges에서 profiles fallback 생성.
- 네트워크/Auth 예외(SocketException, AuthRetryableFetchException)는 `FlutterError.onError`에서 크래시 방지 처리.

## 라우팅
- `go_router` ^14.6.3, `routerProvider`가 auth 스트림(`GoRouterRefreshStream`)에 반응해 redirect.

> 세부 화면-프로바이더 매핑이 필요해지면 이 페이지에 표로 추가(압축 유지).
