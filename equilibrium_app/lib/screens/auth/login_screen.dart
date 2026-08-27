import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegistering = false;

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    
    final auth = context.read<AuthProvider>();
    auth.clearError();
    if (_isRegistering) {
      await auth.register(email, password);
    } else {
      await auth.login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EqTokens.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'EQUILIBRIUM',
                textAlign: TextAlign.center,
                style: context.eqText.headlineLarge?.copyWith(
                  letterSpacing: 2,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: EqTokens.space8),
              Text(
                'Autonomous Student Workload Balancer',
                textAlign: TextAlign.center,
                style: context.eqText.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space48),
              if (auth.errorMessage != null) ...[
                Text(
                  auth.errorMessage!,
                  style: context.eqText.bodyMedium?.copyWith(color: colors.danger),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EqTokens.space16),
              ],
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: EqTokens.space16),
              TextField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                ),
                obscureText: true,
              ),
              const SizedBox(height: EqTokens.space32),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: auth.isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                    : Text(_isRegistering ? 'Create Account' : 'Sign In', style: context.eqText.labelLarge?.copyWith(color: colors.surface)),
              ),
              const SizedBox(height: EqTokens.space16),
              TextButton(
                onPressed: () {
                  setState(() => _isRegistering = !_isRegistering);
                  auth.clearError();
                },
                child: Text(
                  _isRegistering ? 'Already have an account? Sign in' : "Don't have an account? Create one",
                  style: context.eqText.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
