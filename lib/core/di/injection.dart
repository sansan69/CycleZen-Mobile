import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:cyclezen/core/router/app_router.dart';
import 'package:cyclezen/features/auth/bloc/auth_bloc.dart';
import 'package:cyclezen/data/repositories/auth_repository.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';
import 'package:cyclezen/data/repositories/ride_repository.dart';
import 'package:cyclezen/features/ride/services/ride_tracking_service.dart';
import 'package:cyclezen/data/services/achievement_service.dart';
import 'package:cyclezen/data/services/training_service.dart';
import 'package:cyclezen/data/services/weather_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({GlobalKey<NavigatorState>? navigatorKey}) async {
  // Router
  getIt.registerLazySingleton<AppRouter>(() => AppRouter(navigatorKey: navigatorKey));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository());
  getIt.registerLazySingleton<RouteRepository>(() => RouteRepository());
  getIt.registerLazySingleton<RideRepository>(() => RideRepository());

  // Services
  getIt.registerLazySingleton<RideTrackingService>(() => RideTrackingService());
  getIt.registerLazySingleton<AchievementService>(() => AchievementService());
  getIt.registerLazySingleton<TrainingService>(() => TrainingService());
  getIt.registerLazySingleton<WeatherService>(() => WeatherService());

  // BLoCs
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
}
