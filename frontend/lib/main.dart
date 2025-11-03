import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/user_provider.dart';
import 'features/login/screens/login_screen.dart';
import 'features/main_tab/main_tab_screen.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ko_KR');

    final userProvider = UserProvider();
    await userProvider.loadUser();

    debugPrint('🔑 복원된 유저: id=${userProvider.userId}, 로그인상태=${userProvider.isLoggedIn}');

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

    runApp(
      ChangeNotifierProvider.value(
        value: userProvider,
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
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
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ko', 'KR'),
      home: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoggedIn) {
            debugPrint('✅ 로그인 유지됨 → 홈 진입 (id=${userProvider.userId})');
            return const MainTabScreen();
          } else {
            debugPrint('🚪 로그인 필요 → 로그인 화면으로');
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
