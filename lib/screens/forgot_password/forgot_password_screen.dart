import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safechain/modals/success_modal.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:slider_captcha/slider_captcha.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  void _initiatePasswordReset() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) {
          return SliderCaptcha(
            image: Image.asset(
              'images/logo.png',
              fit: BoxFit.fitWidth,
            ),
            onConfirm: (value) async {
              Navigator.of(context).pop();
              if (value) {
                await _handlePasswordReset();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CAPTCHA verification failed.')),
                );
              }
            },
          );
        },
      );
    }
  }

  Future<void> _handlePasswordReset() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => const SuccessModal(
          title: 'Link Sent',
          message: 'A password reset link was sent to your email.',
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF20C997),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 40),
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 80,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(
                                    child: Text(
                                      'Reset Password',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF20C997),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: Text(
                                      'Enter your email to receive a password reset link.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your email',
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your email';
                                      if (!value.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _initiatePasswordReset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF20C997),
                                      minimumSize: const Size(double.infinity, 56),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Send Reset Link', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Remembered your password? "),
                                      GestureDetector(
                                        onTap: () => Navigator.of(context).pop(),
                                        child: const Text(
                                          'Sign In',
                                          style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 30,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset('images/logo.png', height: 80),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
