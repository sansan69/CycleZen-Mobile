import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cyclezen/core/config/firebase_config.dart';
import 'package:cyclezen/core/di/injection.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/core/router/app_router.dart';
import 'package:cyclezen/features/auth/bloc/auth_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash immediately — don't wait for Firebase init.
  runApp(const _CycleZenSplash());

  _initApp().then((_) {
    runApp(CycleZenApp(themeNotifier: getIt<ThemeModeNotifier>()));
  });
}

Future<void> _initApp() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final themeNotifier = ThemeModeNotifier();
  getIt.registerSingleton<ThemeModeNotifier>(themeNotifier);

  await configureDependencies();
}

/// Branded splash screen shown immediately while Firebase initializes.
class _CycleZenSplash extends StatelessWidget {
  const _CycleZenSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.brandGradient),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CycleZenSplashMark(),
                SizedBox(height: 20),
                Text(
                  'CycleZen',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'DISCOVER · PLAN · RIDE · SHARE',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppTheme.goldRing,
                  ),
                ),
                SizedBox(height: 34),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: AppTheme.goldRing,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleZenSplashMark extends StatelessWidget {
  const _CycleZenSplashMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/cyclezen_mark_transparent.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

class CycleZenApp extends StatelessWidget {
  final ThemeModeNotifier themeNotifier;

  const CycleZenApp({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthEventAppStarted()),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            title: 'CycleZen',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: getIt<AppRouter>().config,
          );
        },
      ),
    );
  }
}
