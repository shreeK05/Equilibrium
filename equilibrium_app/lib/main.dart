import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme.dart';
import 'widgets/layout/app_shell.dart';
import 'core/state/schedule_provider.dart';
import 'core/state/auth_provider.dart';
import 'core/state/profile_provider.dart';
import 'core/state/timer_provider.dart';
import 'core/state/exam_provider.dart';
import 'core/api/api_client.dart';
import 'services/auth_repository.dart';
import 'services/constraint_repository.dart';
import 'services/notification_service.dart';
import 'services/decision_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://equilibrium-42g8.onrender.com/api/v1',
  );
  final api = ApiClient(baseUrl: apiUrl);

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => api),
        Provider(create: (_) => ConstraintRepository(api)),
        Provider(create: (_) => DecisionRepository(api)),
        ChangeNotifierProvider(create: (_) {
          final authRepo = AuthRepository(api);
          final provider = AuthProvider(authRepo);
          api.onUnauthorized = () => provider.forceLogout();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => ScheduleProvider(api)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(api)),
        ChangeNotifierProvider(create: (_) => TimerProvider(api)),
        ChangeNotifierProvider(create: (_) => ExamProvider(api)),
      ],
      child: const EquilibriumApp(),
    ),
  );
}

class EquilibriumApp extends StatelessWidget {
  const EquilibriumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        return MaterialApp(
          title: 'Equilibrium',
          debugShowCheckedModeBanner: false,
          theme: EqTheme.lightTheme,
          darkTheme: EqTheme.darkTheme,
          themeMode: profileProvider.themeMode,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.status == AuthStatus.initial) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (auth.status == AuthStatus.unauthenticated) {
                return const LoginScreen();
              }
              if (auth.isFirstRun) {
                return const OnboardingScreen();
              }
              return const AppShell();
            },
          ),
        );
      },
    );
  }
}