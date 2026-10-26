import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:equilibrium_app/core/theme/theme.dart';
import 'package:equilibrium_app/core/state/auth_provider.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/screens/auth/login_screen.dart';
import 'package:equilibrium_app/screens/auth/otp_verification_screen.dart';

void main() {
  Widget createAuthWidget(Widget child) {
    final api = ApiClient(baseUrl: 'http://localhost:3000/api/v1');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository(api))),
      ],
      child: MaterialApp(
        theme: EqTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Milestone 6 — Flutter Email OTP Registration UX', () {
    testWidgets('LoginScreen shows Full Name and password min-length hints in registration mode', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthWidget(const LoginScreen()));

      // Initially in Sign In mode
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Full Name (Optional)'), findsNothing);

      // Toggle to registration
      await tester.tap(find.text('Don\'t have an account? Create one'));
      await tester.pumpAndSettle();

      // Now shows Full Name field and Create Account button
      expect(find.text('Full Name (Optional)'), findsOneWidget);
      expect(find.text('Password (min. 8 characters)'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen displays email, 6-digit boxes, and countdown', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthWidget(
        const OtpVerificationScreen(
          email: 'student@example.com',
          name: 'Alex Chen',
        ),
      ));
      await tester.pump();

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('student@example.com'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Verify & Complete Registration'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen handles 6-digit input and validates length', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthWidget(
        const OtpVerificationScreen(
          email: 'student@example.com',
        ),
      ));
      await tester.pump();

      // Tapping Verify with empty input is disabled
      final verifyBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(verifyBtn.onPressed, isNull);

      // Enter 5 digits: button remains disabled
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      await tester.enterText(textFieldFinder, '12345');
      await tester.pump();
      final fiveDigitBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(fiveDigitBtn.onPressed, isNull);

      // Visual boxes render typed digits
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen allows editing email by popping back', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthWidget(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const OtpVerificationScreen(email: 'typo@example.com'),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('typo@example.com'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pump();
    });
  });
}
