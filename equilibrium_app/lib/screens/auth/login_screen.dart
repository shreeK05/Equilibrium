import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    
    final auth = context.read<AuthProvider>();
    auth.clearError();
    if (_isRegistering) {
      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 8 characters long.')),
        );
        return;
      }
      final success = await auth.registerRequest(email, password, name: name.isNotEmpty ? name : null);
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: email,
              name: name.isNotEmpty ? name : null,
            ),
          ),
        );
      }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(EqTokens.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EqTokens.space32),
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
              if (_isRegistering) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name (Optional)',
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                  ),
                  textCapitalization: TextCapitalization.words,
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
                  labelText: 'Password (min. 8 characters)',
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
                    : Text(
                        _isRegistering ? 'Create Account' : 'Sign In',
                        style: context.eqText.labelLarge?.copyWith(color: colors.surface, fontWeight: FontWeight.bold),
                      ),
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
              if (!_isRegistering)
                TextButton(
                  onPressed: () {
                    auth.clearError();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                  },
                  child: Text(
                    'Forgot password?',
                    style: context.eqText.bodyMedium?.copyWith(color: colors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
