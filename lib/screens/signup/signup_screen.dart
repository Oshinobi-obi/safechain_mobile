import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/modals/success_modal.dart';
import 'package:safechain/modals/error_modal.dart';
import 'package:safechain/screens/login/login_screen.dart';
import 'package:safechain/services/connectivity_service.dart';
import 'package:safechain/widgets/fade_page_route.dart';
import 'package:safechain/widgets/offline_banner.dart';
import 'package:slider_captcha/slider_captcha.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  String? _emailErrorText;

  double _passwordStrength = 0;
  final RegExp _upperRegExp = RegExp(r'[A-Z]');
  final RegExp _lowerRegExp = RegExp(r'[a-z]');
  final RegExp _specialRegExp = RegExp(r'[!@#$%^&*(),.?\":{}|<>_]');
  final RegExp _numberRegExp = RegExp(r'[0-9]');

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    String p = _passwordController.text;
    double strength = 0;
    if (p.isEmpty) {
      strength = 0;
    } else {
      if (p.length >= 8) strength += 0.2;
      if (_upperRegExp.hasMatch(p)) strength += 0.2;
      if (_lowerRegExp.hasMatch(p)) strength += 0.2;
      if (_specialRegExp.hasMatch(p)) strength += 0.2;
      if (_numberRegExp.hasMatch(p)) strength += 0.2;
    }
    setState(() {
      _passwordStrength = strength;
    });
  }

  Color _getStrengthColor() {
    if (_passwordStrength <= 0.4) return Colors.red;
    if (_passwordStrength <= 0.8) return Colors.yellow;
    return Colors.green;
  }

  void _initiateSignup() {
    // Block the action when offline.
    if (!ConnectivityService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clear previous server-side error before validating
    setState(() {
      _emailErrorText = null;
    });

    if (_formKey.currentState!.validate() && _agreedToTerms) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SliderCaptcha(
                image: Image.asset(
                  'images/logo.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                onConfirm: (value) async {
                  Navigator.of(context).pop();
                  if (value) {
                    await _handleSignup();
                  } else {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => const ErrorModal(
                          title: 'Verification Failed',
                          message: 'CAPTCHA verification failed. Please try again.',
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);

    const String apiUrl = 'https://safechain.site/api/mobile/register.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'name': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      final responseBody = jsonDecode(response.body);
      final message = responseBody['message'] ?? 'An unknown error occurred.';

      if (!mounted) return;

      if (response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const SuccessModal(
            title: 'Account Registration Success!',
            message: 'Redirecting to Login Page...',
          ),
        );

        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            FadePageRoute(child: const LoginScreen()),
                (route) => false,
          );
        }
      } else if (response.statusCode == 409) {
        // Handle specific error for email already in use
        setState(() {
          _emailErrorText = message;
        });
      } else {
        // Handle all other errors with ErrorModal
        showDialog(
          context: context,
          builder: (_) => ErrorModal(
            title: 'Registration Failed',
            message: message,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => const ErrorModal(
            title: 'Unexpected Error',
            message: 'Could not connect to the server. Please check your internet connection.',
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordStrength);
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Show Terms & Policy modal ────────────────────────────────
  Future<void> _showTermsModal() async {
    final ScrollController scrollController = ScrollController();
    bool hasScrolledToBottom = false;
    bool hasStartedScrolling = false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            scrollController.addListener(() {
              if (!hasStartedScrolling && scrollController.offset > 10) {
                setModalState(() => hasStartedScrolling = true);
              }
              if (!hasScrolledToBottom &&
                  scrollController.offset >=
                      scrollController.position.maxScrollExtent - 40) {
                setModalState(() => hasScrolledToBottom = true);
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF20C997),
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.article_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Terms & Privacy Policy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ),

                  // Scroll hint — hidden once user starts scrolling
                  if (!hasStartedScrolling)
                    Container(
                      color: const Color(0xFFFFFBEB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: const [
                          Icon(Icons.swipe_down_rounded,
                              color: Color(0xFFD97706), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Please scroll to the bottom to accept.',
                            style: TextStyle(
                                color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Scrollable content
                  Flexible(
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Last updated: January 2025',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            SizedBox(height: 16),

                            // Terms of Use
                            Text('Terms of Use',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF20C997))),
                            SizedBox(height: 8),
                            Text('1. Acceptance of Terms',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'By creating an account and using SafeChain, you agree to be bound by these Terms of Use. The app is intended for registered residents and authorized users only.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('2. Responsible Use',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'You agree to use SafeChain solely for its intended emergency response and device management purposes. False emergency alerts are strictly prohibited and may result in account suspension and coordination with local authorities.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('3. Account Responsibility',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'You are responsible for maintaining the confidentiality of your account credentials. You must notify us immediately if you suspect unauthorized access to your account.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('4. Device Registration',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'Each SafeChain device may only be registered to one resident account at a time. Transferring or sharing device access without authorization is prohibited.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('5. Limitation of Liability',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'SafeChain is a tool to assist in emergencies. Response times depend on network connectivity and responder availability. We are not liable for delays or failures outside our reasonable control.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),

                            SizedBox(height: 24),
                            Divider(),
                            SizedBox(height: 16),

                            // Privacy Policy
                            Text('Privacy Policy',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF20C997))),
                            SizedBox(height: 8),
                            Text('1. Data We Collect',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'We collect your full name, email address, contact number, home address, and device information. We may also collect GPS location data from your registered SafeChain device during active tracking sessions.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('2. How We Use Your Data',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'Your data is used exclusively to provide SafeChain services including emergency alerts, GPS tracking, and device management. We do not sell or share your personal information with third parties.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('3. Data Security',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'All data is transmitted over HTTPS encryption. We implement industry-standard security measures to protect your information from unauthorized access or disclosure.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('4. Data Retention',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'We retain your data for as long as your account is active. You may request deletion of your account and all associated data at any time by contacting support.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 12),
                            Text('5. Your Rights',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'You have the right to access, correct, or delete your personal data. You may also withdraw consent at any time, though this may affect your ability to use certain features of the app.',
                              style: TextStyle(height: 1.5, color: Colors.black87),
                            ),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Accept button — full width, enabled only after scrolling to bottom
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: hasScrolledToBottom
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20C997),
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          hasScrolledToBottom ? 'Accept' : 'Scroll to Accept',
                          style: TextStyle(
                            fontSize: 16,
                            color: hasScrolledToBottom
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (accepted == true) {
      setState(() => _agreedToTerms = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF20C997),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SafeArea(
              top: false,
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
                                            'Sign up',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF20C997),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _fullNameController,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            hintText: 'Enter your Full Name',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Enter your full name';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _emailController,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          onChanged: (_) {
                                            if (_emailErrorText != null) {
                                              setState(() {
                                                _emailErrorText = null;
                                              });
                                            }
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'Enter your email',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                            errorText: _emailErrorText,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Enter your email';
                                            }
                                            if (!value.contains('@')) {
                                              return 'Enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            hintText: 'Create a password',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Enter a password';
                                            }
                                            if (value.length < 8) {
                                              return 'Password must be at least 8 characters';
                                            }
                                            if (!_upperRegExp.hasMatch(value)) {
                                              return 'Add at least 1 uppercase letter';
                                            }
                                            if (!_lowerRegExp.hasMatch(value)) {
                                              return 'Add at least 1 lowercase letter';
                                            }
                                            if (!_numberRegExp.hasMatch(value)) {
                                              return 'Add at least 1 number';
                                            }
                                            if (!_specialRegExp.hasMatch(value)) {
                                              return 'Add at least 1 special character';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: _passwordStrength,
                                            backgroundColor: Colors.grey[200],
                                            color: _getStrengthColor(),
                                            minHeight: 5,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _confirmPasswordController,
                                          obscureText: _obscureConfirmPassword,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            hintText: 'Confirm your password',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Confirm your password';
                                            }
                                            if (value != _passwordController.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _agreedToTerms,
                                              onChanged: (value) {
                                                if (value == true) {
                                                  // Show modal — only check if user accepts
                                                  _showTermsModal();
                                                } else {
                                                  setState(() => _agreedToTerms = false);
                                                }
                                              },
                                              activeColor: const Color(0xFF20C997),
                                              checkColor: Colors.white,
                                              side: const BorderSide(color: Color(0xFF4B5563), width: 1.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: _showTermsModal,
                                                child: Text.rich(
                                                  TextSpan(
                                                    text: 'I agree to Safechain\'s ',
                                                    children: [
                                                      TextSpan(
                                                        text: 'Terms',
                                                        style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold),
                                                      ),
                                                      TextSpan(text: ' and '),
                                                      TextSpan(
                                                        text: 'Privacy Policy',
                                                        style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 32),
                                        ElevatedButton(
                                          onPressed: _agreedToTerms && !_isLoading ? _initiateSignup : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _agreedToTerms ? const Color(0xFF20C997) : Colors.grey,
                                            minimumSize: const Size(double.infinity, 56),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                            elevation: 0,
                                          ),
                                          child: _isLoading
                                              ? const CircularProgressIndicator(color: Colors.white)
                                              : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(height: 40),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('Already have an account? '),
                                            GestureDetector(
                                              onTap: () => Navigator.pushReplacement(
                                                context,
                                                FadePageRoute(child: const LoginScreen()),
                                              ),
                                              child: const Text(
                                                'Sign In',
                                                style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
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
          ),
        ],
      ),
    );
  }
}