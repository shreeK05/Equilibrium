import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? name;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.name,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _cooldownTimer;
  int _cooldownSeconds = 60;
  bool _isResending = false;
  String? _localError;
  String? _localSuccessMessage;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    // Auto-focus the OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldownTimer([int initialSeconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = initialSeconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _cooldownSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cooldownSeconds--;
          });
        }
      }
    });
  }

  Future<void> _submitVerification([String? code]) async {
    final otp = (code ?? _otpController.text).trim();
    if (otp.length != 6) {
      setState(() {
        _localError = 'Please enter all 6 digits of the verification code.';
      });
      return;
    }

    setState(() {
      _localError = null;
      _localSuccessMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(widget.email, otp);

    if (success && mounted) {
      // Pop any auth sub-screens so root navigator displays main app
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      setState(() {
        _localError = auth.errorMessage ?? 'Verification failed. Please check the code.';
      });
    }
  }

  Future<void> _resendCode() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _localError = null;
      _localSuccessMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.resendOtp(widget.email);

    if (mounted) {
      setState(() {
        _isResending = false;
      });

      if (success) {
        setState(() {
          _localSuccessMessage = 'A new 6-digit code has been sent to your email.';
          _otpController.clear();
        });
        _startCooldownTimer(60);
      } else {
        setState(() {
          _localError = auth.errorMessage ?? 'Unable to resend code. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final auth = context.watch<AuthProvider>();
    final isBusy = auth.isLoading || _isResending;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: isBusy ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space32, vertical: EqTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EqTokens.space16),
              // Icon Header
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_read_outlined, size: 32, color: colors.primary),
                ),
              ),
              const SizedBox(height: EqTokens.space24),
              Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: context.eqText.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: EqTokens.space8),
              Text(
                'We sent a 6-digit verification code to',
                textAlign: TextAlign.center,
                style: context.eqText.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: context.eqText.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: EqTokens.space8),
                  GestureDetector(
                    onTap: isBusy ? null : () => Navigator.pop(context),
                    child: Text(
                      'Edit',
                      style: context.eqText.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space32),

              // Feedback Banners
              if (_localError != null || auth.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(EqTokens.space12),
                  decoration: BoxDecoration(
                    color: colors.danger.withValues(alpha: 0.1),
                    borderRadius: EqTokens.border8,
                    border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.danger, size: 20),
                      const SizedBox(width: EqTokens.space8),
                      Expanded(
                        child: Text(
                          _localError ?? auth.errorMessage!,
                          style: context.eqText.bodySmall?.copyWith(color: colors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EqTokens.space16),
              ],

              if (_localSuccessMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(EqTokens.space12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: EqTokens.border8,
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      const SizedBox(width: EqTokens.space8),
                      Expanded(
                        child: Text(
                          _localSuccessMessage!,
                          style: context.eqText.bodySmall?.copyWith(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EqTokens.space16),
              ],

              // 6-Digit PIN Display & Hidden TextField
              Stack(
                alignment: Alignment.center,
                children: [
                  // Hidden Native TextField for complete keyboard and clipboard support
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _otpController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        setState(() {});
                        if (val.length == 6) {
                          _submitVerification(val);
                        }
                      },
                    ),
                  ),
                  // Visual 6-Box Display
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final text = _otpController.text;
                        final digit = index < text.length ? text[index] : '';
                        final isFocused = _focusNode.hasFocus && index == text.length;

                        return Container(
                          width: 46,
                          height: 54,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: EqTokens.border8,
                            border: Border.all(
                              color: isFocused
                                  ? colors.primary
                                  : digit.isNotEmpty
                                      ? colors.textPrimary.withValues(alpha: 0.4)
                                      : colors.surface,
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            digit,
                            style: context.eqText.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space32),

              // Verify Button
              ElevatedButton(
                onPressed: (isBusy || _otpController.text.length != 6)
                    ? null
                    : () => _submitVerification(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: isBusy
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2),
                      )
                    : Text(
                        'Verify & Complete Registration',
                        style: context.eqText.labelLarge?.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: EqTokens.space24),

              // Resend Countdown & Action
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: context.eqText.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                  if (_cooldownSeconds > 0)
                    Text(
                      'Resend in ${_cooldownSeconds}s',
                      style: context.eqText.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: isBusy ? null : _resendCode,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Resend Code',
                        style: context.eqText.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: EqTokens.space16),

              Text(
                'Codes expire after 10 minutes. For security, maximum 5 attempts are allowed per code.',
                textAlign: TextAlign.center,
                style: context.eqText.bodySmall?.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
