import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/modals/error_modal.dart';
import 'package:safechain/modals/success_modal.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  double _passwordStrength = 0;
  final RegExp _upperRegExp = RegExp(r'[A-Z]');
  final RegExp _lowerRegExp = RegExp(r'[a-z]');
  final RegExp _specialRegExp = RegExp(r'[!@#$%^&*(),.?\":{}|<>_]');
  final RegExp _numberRegExp = RegExp(r'[0-9]');


  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    String p = _newPasswordController.text;
    double strength = 0;
    if (p.isEmpty) {
      strength = 0;
    } else {
      if (p.length >= 8) strength += 0.20;
      if (_upperRegExp.hasMatch(p)) strength += 0.20;
      if (_lowerRegExp.hasMatch(p)) strength += 0.20;
      if (_numberRegExp.hasMatch(p)) strength += 0.20;
      if (_specialRegExp.hasMatch(p)) strength += 0.20;
    }
    setState(() {
      _passwordStrength = strength;
    });
  }

  Color _getStrengthColor() {
    if (_passwordStrength <= 0.25) return Colors.red;
    if (_passwordStrength <= 0.75) return Colors.yellow;
    return Colors.green;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = await SessionManager.getUser();
    if (user == null) {
      showDialog(
        context: context,
        builder: (_) => const ErrorModal(
          title: 'Not Logged In',
          message: 'Your session has expired. Please log in again.',
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    const String apiUrl = 'https://safechain.site/api/mobile/change_password.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'resident_id': user.residentId,
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      final responseBody = jsonDecode(response.body);
      final message = responseBody['message'] ?? 'An error occurred.';

      if (!mounted) return;

      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        await NotificationService.addNotification(
          'Security Alert',
          'Your password was changed successfully.',
          NotificationType.security,
        );
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => SuccessModal(
            title: 'Password Changed',
            message: message,
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        showDialog(
          context: context,
          builder: (_) => ErrorModal(
            title: 'Change Failed',
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordField('Current Password', _currentPasswordController, _obscureCurrentPassword, () {
                setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
              }),
              const SizedBox(height: 24),
              _buildPasswordField('New Password', _newPasswordController, _obscureNewPassword, () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              }, (value) {
                if (value == null || value.isEmpty) return 'Please enter a new password';
                if (value.length < 8) return 'Password must be at least 8 characters';
                if (value == _currentPasswordController.text) {
                  return 'New password must be different from your current password';
                }
                return null;
              }),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey[200],
                    color: _getStrengthColor(),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordRequirement('At least 8 Characters', _newPasswordController.text.length >= 8),
              _buildPasswordRequirement('At least 1 Uppercase', _upperRegExp.hasMatch(_newPasswordController.text)),
              _buildPasswordRequirement('At least 1 Number', _numberRegExp.hasMatch(_newPasswordController.text)),
              _buildPasswordRequirement('At least 1 Special Character', _specialRegExp.hasMatch(_newPasswordController.text)),
              const SizedBox(height: 24),
              _buildPasswordField('Confirm New Password', _confirmPasswordController, _obscureConfirmPassword, () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              }, (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              }),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20C997),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscureText, VoidCallback toggleObscure, [String? Function(String?)? validator]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            fillColor: const Color(0xFFF1F5F9),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: toggleObscure,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirement(String text, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.cancel, color: met ? Colors.green : Colors.red, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: met ? Colors.green : Colors.red)),
      ],
    );
  }
}