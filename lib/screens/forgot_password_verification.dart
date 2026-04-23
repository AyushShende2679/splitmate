import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timer_button/timer_button.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';
import 'dart:ui';

class ForgotPasswordVerificationPage extends StatefulWidget {
  final String email;
  const ForgotPasswordVerificationPage({super.key, required this.email});

  @override
  State<ForgotPasswordVerificationPage> createState() =>
      _ForgotPasswordVerificationPageState();
}

class _ForgotPasswordVerificationPageState
    extends State<ForgotPasswordVerificationPage> {
  bool _isResending = false;

  Future<void> resendLink() async {
    if (_isResending) return;

    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset link re-sent to ${widget.email}'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error resending link'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white),
      body: Stack(
        children: [
          AppTheme.darkScaffoldBackground(extraOrbs: [
            AppTheme.backgroundOrb(top: 250, left: -50, size: 180, color: AppTheme.success, opacity: 0.2),
          ]),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, size: 38, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text("Check Your Email", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text("We've sent you a reset link", style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                      const SizedBox(height: 32),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            decoration: AppTheme.glassDecoration(borderRadius: 24),
                            child: Column(
                              children: [
                                Text(
                                  'We have sent a password reset link to:',
                                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.email,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'If you do not receive the email within a few minutes, please check your spam folder.',
                                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Closing the app will restart the process.',
                                          style: TextStyle(color: AppTheme.danger, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TimerButton(
                                  label: 'Didn\'t receive? Send again.',
                                  activeTextStyle: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600),
                                  disabledTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                  onPressed: () {
                                    if (!_isResending) {
                                      resendLink();
                                    }
                                  },
                                  timeOutInSeconds: 60,
                                  buttonType: ButtonType.textButton,
                                  disabledColor: Colors.transparent,
                                  color: Colors.transparent,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 8,
                                      shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                                      backgroundColor: AppTheme.primary,
                                    ),
                                    child: const Text("Back to Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}