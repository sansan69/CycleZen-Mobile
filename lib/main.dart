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

  // Show splash immediately — don't wait for Firebase init
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

/// Minimal splash screen shown immediately while Firebase initializes.
class _CycleZenSplash extends StatelessWidget {
  const _CycleZenSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              // Gold ring accent
              Icon(Icons.pedal_bike, size: 80, color: AppTheme.goldRing),
              SizedBox(height: 16),
              Text(
                'CycleZen',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Find your ride',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: AppTheme.mintCenter,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.goldRing,
                ),
              ),
            ],
          ),
        ),
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
