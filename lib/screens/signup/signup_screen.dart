import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safechain/modals/success_modal.dart';
import 'package:safechain/screens/login/login_screen.dart';
import 'package:safechain/widgets/phone_number_input.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyNumberController = TextEditingController();
  final _emergencyAddressController = TextEditingController();

  double _passwordStrength = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final RegExp _hasUpperCase = RegExp(r'[A-Z]');
  final RegExp _hasLowerCase = RegExp(r'[a-z]');
  final RegExp _hasNumber = RegExp(r'[0-9]');
  final RegExp _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  void _updatePasswordStrength() {
    String password = _passwordController.text;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (_hasUpperCase.hasMatch(password)) strength += 0.25;
    if (_hasLowerCase.hasMatch(password)) strength += 0.25;
    if (_hasNumber.hasMatch(password)) strength += 0.15;
    if (_hasSpecialChar.hasMatch(password)) strength += 0.10;
    setState(() => _passwordStrength = strength);
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('residents').doc(userCredential.user!.uid).set({
          'full_name': _fullNameController.text,
          'address': _addressController.text,
          'contact_number': _contactNumberController.text.replaceAll('-', ''),
          'email': _emailController.text,
          'emergency_contact_person_name': _emergencyNameController.text,
          'emergency_contact_number': _emergencyNumberController.text.replaceAll('-', ''),
          'emergency_contact_address': _emergencyAddressController.text,
          'registered_date': Timestamp.now(),
          'profile_picture_url': null,
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const SuccessModal(
            title: 'Account Registration Success!',
            message: 'Redirecting to Login Page...',
          ),
        );

        await Future.delayed(const Duration(seconds: 3));

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.removeListener(() => setState(() {}));
    _confirmPasswordController.removeListener(() => setState(() {}));
    _fullNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emergencyNameController.dispose();
    _emergencyNumberController.dispose();
    _emergencyAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('images/logo.png', height: 100),
                const SizedBox(height: 32),
                _buildSignupForm(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(label: _buildRequiredLabel('Full Name'), hintText: 'Enter your full name'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'This field cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(label: _buildRequiredLabel('Email'), hintText: 'Enter your email address'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'This field cannot be empty';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(label: _buildRequiredLabel('Complete Address'), hintText: 'Enter your complete address'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'This field cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PhoneNumberInput(label: 'Contact Number', hint: '912-345-6789', controller: _contactNumberController),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  label: _buildRequiredLabel('Password'),
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a password';
                  if (_passwordStrength < 0.9) return 'Password is too weak';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.grey[300],
                color: _passwordStrength <= 0.3 ? Colors.red : _passwordStrength <= 0.6 ? Colors.yellow : Colors.green,
                minHeight: 5,
              ),
              const SizedBox(height: 8),
              Text('8+ chars, upper & lower case, number, special char.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  label: _buildRequiredLabel('Confirm Password'),
                  hintText: 'Re-enter your password',
                  errorText: _confirmPasswordController.text.isNotEmpty && _passwordController.text != _passwordController.text ? 'Passwords do not match' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm your password';
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyNameController,
                decoration: InputDecoration(label: _buildRequiredLabel('Emergency Contact Person Name'), hintText: 'Enter name'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'This field cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PhoneNumberInput(label: 'Emergency Contact Number', hint: '912-345-6789', controller: _emergencyNumberController),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyAddressController,
                decoration: InputDecoration(label: _buildRequiredLabel('Emergency Contact Address'), hintText: 'Enter address'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'This field cannot be empty';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C997),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false), child: const Text('Login')),
                ],
              )
            ],
          ),
        ));
  }

  RichText _buildRequiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.grey[600], fontSize: 16),
        children: const <TextSpan>[
          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}