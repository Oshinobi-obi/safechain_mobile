import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/services/connectivity_service.dart';   // ← NEW
import 'package:safechain/screens/home/home_screen.dart';
import 'package:safechain/screens/signup/signup_screen.dart';
import 'package:safechain/screens/forgot_password/forgot_password_screen.dart';
import 'package:safechain/modals/error_modal.dart';
import 'package:safechain/widgets/fade_page_route.dart';
import 'package:safechain/widgets/offline_banner.dart';           // ← NEW

// ── Key used to persist the Remember Me preference ────────────────────────
// Kept here so both read & write always use the same literal.
const _kRememberMeKey = 'rememberMeEnabled';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // ── Auto-login (only when Remember Me was previously checked) ─────────────
  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMeEnabled = prefs.getBool(_kRememberMeKey) ?? false;

    if (rememberMeEnabled) {
      // User opted in to persistent login — skip the login screen.
      final isLoggedIn = await SessionManager.isLoggedIn();
      if (isLoggedIn && mounted) {
        Navigator.of(context).pushReplacement(
          FadePageRoute(child: const HomeScreen()),
        );
        return;
      }
    } else {
      // No Remember Me — clear any stale session so they must log in fresh.
      await SessionManager.logout();
    }

    _loadRememberedEmail();
  }

  void _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('rememberedEmail');
    if (email != null && mounted) {
      _emailController.text = email;
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Block the action when offline — the button is still tappable so the user
    // gets feedback instead of a silent failure.
    if (!ConnectivityService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    const String apiUrl = 'https://safechain.site/api/mobile/login.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      final responseBody = jsonDecode(response.body);
      final message = responseBody['message'] ?? 'An unknown error occurred.';

      if (!mounted) return;

      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        // Save user session.
        final user = UserModel.fromJson(responseBody['user']);
        await SessionManager.saveUser(user);

        // Persist the Remember Me preference so _checkLoginStatus knows what
        // to do on the next cold start.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kRememberMeKey, _rememberMe);

        if (_rememberMe) {
          await prefs.setString('rememberedEmail', _emailController.text.trim());
        } else {
          await prefs.remove('rememberedEmail');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          FadePageRoute(child: const HomeScreen()),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) =>
              ErrorModal(title: 'Login Failed', message: message),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const ErrorModal(
            title: 'An Unexpected Error Occurred',
            message:
            'Could not connect to the server. Please check your internet connection.',
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF20C997),
      // ── Offline banner sits OUTSIDE SafeArea so it hugs the very top ───────
      body: Column(
        children: [
          const OfflineBanner(), // ← NEW: always visible at top of this screen
          Expanded(
            child: SafeArea(
              top: false, // status bar already accounted for by Scaffold
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
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
                                  padding:
                                  const EdgeInsets.fromLTRB(24, 70, 24, 24),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Center(
                                          child: Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF20C997),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text('Email',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _emailController,
                                          autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            hintText: 'Enter your email',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty)
                                              return 'Please enter your email';
                                            if (!value.contains('@'))
                                              return 'Enter a valid email';
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        const Text('Password',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            hintText: 'Enter your password',
                                            fillColor: const Color(0xFFF1F5F9),
                                            filled: true,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () => setState(() =>
                                              _obscurePassword =
                                              !_obscurePassword),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty)
                                              return 'Please enter your password';
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: _rememberMe,
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                      _rememberMe = value!),
                                                  activeColor:
                                                  const Color(0xFF20C997),
                                                  checkColor: Colors.white,
                                                  side: const BorderSide(
                                                      color: Color(0xFF4B5563),
                                                      width: 1.5),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          4)),
                                                ),
                                                const Text('Remember me'),
                                              ],
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  FadePageRoute(
                                                      child:
                                                      const ForgotPasswordScreen()),
                                                );
                                              },
                                              child: const Text(
                                                'Forgot Password',
                                                style: TextStyle(
                                                    color: Color(0xFF20C997),
                                                    fontWeight:
                                                    FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 32),
                                        ElevatedButton(
                                          onPressed:
                                          _isLoading ? null : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                            const Color(0xFF20C997),
                                            minimumSize:
                                            const Size(double.infinity, 56),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(30)),
                                            elevation: 0,
                                          ),
                                          child: _isLoading
                                              ? const CircularProgressIndicator(
                                              color: Colors.white)
                                              : const Text('Sign In',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.bold)),
                                        ),
                                        const SizedBox(height: 40),
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                                'Don\'t have an account? '),
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                FadePageRoute(
                                                    child: const SignupScreen()),
                                              ),
                                              child: const Text(
                                                'Sign Up',
                                                style: TextStyle(
                                                    color: Color(0xFF20C997),
                                                    fontWeight:
                                                    FontWeight.bold),
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
                                  child:
                                  Image.asset('images/logo.png', height: 80),
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