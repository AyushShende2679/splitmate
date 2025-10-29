import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timer_button/timer_button.dart'; 

class ForgotPasswordVerificationPage extends StatefulWidget {
  final String email;
  const ForgotPasswordVerificationPage({Key? key, required this.email})
      : super(key: key);

  @override
  _ForgotPasswordVerificationPageState createState() =>
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
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error resending link'),
            backgroundColor: Colors.redAccent,
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.95),
                  primary.withOpacity(0.80),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
         
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                   
                    child: Icon(Icons.mark_email_read_outlined, size: 46, color: primary),
                  ),
                  const SizedBox(height: 12),
                  const Text("SplitMate",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                          color: Colors.white)),
                  Text("Check your e-mail",
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.95))),
                  const SizedBox(height: 24),
                  
                 
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                       
                        const Text('Check your E-mail',
                            style: TextStyle(
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16.0),

                        
                        Text(
                          'We have sent a password reset link to your email address:',
                          style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16.0),
                        const Text(
                          'If you do not receive the email within a few minutes, please check your spam folder.',
                          style: TextStyle(fontSize: 14.0, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16.0),
                        
                        
                        const Text(
                          'Warning: If you close the app, you will start the process from the beginning.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.redAccent, fontSize: 14.0),
                        ),
                        const SizedBox(height: 24.0),

                        
                        TimerButton(
                          label: 'Did not receive the email? Send again.',
                          activeTextStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
                          disabledTextStyle: const TextStyle(color: Colors.grey),
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
                        const SizedBox(height: 24.0),
                        
                        
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("BACK",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}