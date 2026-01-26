import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/modals/success_modal.dart';
import 'package:safechain/screens/login/login_screen.dart';
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
    if (_formKey.currentState!.validate() && _agreedToTerms) {
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
                await _handleSignup();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CAPTCHA verification failed.')),
                  );
                }
              }
            },
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
        // Sending data as form fields instead of JSON
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
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
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
                                          setState(() {
                                            _agreedToTerms = value ?? false;
                                          });
                                        },
                                        activeColor: const Color(0xFF20C997),
                                        checkColor: Colors.white,
                                        side: const BorderSide(color: Color(0xFF4B5563), width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                      Expanded(
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
                                                text: 'Policy',
                                                style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold),
                                              ),
                                            ],
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
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
    );
  }
}
