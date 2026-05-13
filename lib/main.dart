import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/router.dart';
import 'core/theme/app_theme.dart';
import 'services/supabase/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 로드
  await dotenv.load(fileName: '.env');

  // 카카오 SDK 초기화 (Native App Key 사용)
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
  );

  // 네이버 지도 SDK 초기화 (C1 수정: main()에서 명시적 초기화 + onAuthFailed 핸들러)
  // deprecated NaverMapSdk.instance.initialize → FlutterNaverMap().init() 으로 교체
  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
    onAuthFailed: (error) {
      debugPrint('[NaverMap] 인증 실패: $error');
      // 인증 실패 시 지도 화면 에러 상태 위젯에서 처리
    },
  );

  // Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Google/Apple OAuth 콜백 후 profiles 자동 생성 (B안 fallback)
  // signInWithOAuth는 딥링크 콜백 방식이므로 authStateChanges 리스너에서 처리합니다.
  final authService = AuthService();
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
      authService.ensureProfile(data.session!.user);
    }
  });

  runApp(
    const ProviderScope(
      child: MuselryApp(),
    ),
  );
}

class MuselryApp extends ConsumerWidget {
  const MuselryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '뮤즐리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
