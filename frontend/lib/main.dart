import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/login/screens/login_screen.dart';

// Kakao SDK import
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: "4774796f75df5e13d71518ffc178ec9a");

  // 키 해시 출력
  final keyHash = await KakaoSdk.origin;
  debugPrint("KAKAO KEY HASH: $keyHash");

  // iOS / Android 에서 카카오 Scheme 이벤트 받기
  kakaoSchemeStream.listen(
    (url) {
      debugPrint("Kakao Redirect URL 수신: $url");
    },
    onError: (e) {
      debugPrint("Kakao Scheme Error: $e");
    },
  );

  // 전역 에러 핸들러
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.empty,
    );
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('WIDGET ERROR: ${details.exceptionAsString()}');
    return const SizedBox.shrink();
  };

  runApp(const MyApp());

  // 비동기 전역 에러
  runZonedGuarded(() async {}, (error, stack) {
    debugPrint('UNCAUGHT: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마음.zip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ko', 'KR'),
      home: const LoginScreen(),
    );
  }
}
