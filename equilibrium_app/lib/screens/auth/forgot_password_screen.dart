import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_error_mapper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _message;
  String? _error;

  void _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final response = await api.post('/auth/forgot-password', body: {'email': email});
      setState(() {
        _message = response?['message'] ?? "If an account exists for this email, we've sent password reset instructions.";
      });
    } on ApiException catch (e) {
      setState(() {
        _error = ApiErrorMapper.getUserFacingMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _error = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EqTokens.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recover Password',
                textAlign: TextAlign.center,
                style: context.eqText.headlineLarge?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: EqTokens.space16),
              Text(
                'Enter your email and we will send you a link to reset your password.',
                textAlign: TextAlign.center,
                style: context.eqText.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space32),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: context.eqText.bodyMedium?.copyWith(color: colors.danger),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EqTokens.space16),
              ],
              if (_message != null) ...[
                Text(
                  _message!,
                  style: context.eqText.bodyMedium?.copyWith(color: colors.success),
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
              const SizedBox(height: EqTokens.space32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                    : Text('Reset Password', style: context.eqText.labelLarge?.copyWith(color: colors.surface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
