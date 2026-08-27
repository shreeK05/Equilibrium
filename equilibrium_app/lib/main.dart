import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme.dart';
import 'widgets/layout/app_shell.dart';
import 'core/state/schedule_provider.dart';
import 'core/state/auth_provider.dart';
import 'core/api/api_client.dart';
import 'services/task_repository.dart';
import 'services/schedule_repository.dart';
import 'services/auth_repository.dart';
import 'services/constraint_repository.dart';
import 'services/decision_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() {
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');
  final api = ApiClient(baseUrl: apiUrl);
  
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => ConstraintRepository(api)),
        Provider(create: (_) => DecisionRepository(api)),
        ChangeNotifierProvider(create: (_) {
          final authRepo = AuthRepository(api);
          final provider = AuthProvider(authRepo);
          api.onUnauthorized = () => provider.forceLogout();
          return provider;
        }),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(
            ScheduleRepository(api),
            TaskRepository(api),
          ),
        ),
      ],
      child: const EquilibriumApp(),
    ),
  );
}

class EquilibriumApp extends StatelessWidget {
  const EquilibriumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Equilibrium',
      debugShowCheckedModeBanner: false,
      theme: EqTheme.lightTheme,
      darkTheme: EqTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.status == AuthStatus.initial) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  }
}