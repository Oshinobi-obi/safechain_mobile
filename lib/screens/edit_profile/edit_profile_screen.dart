import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safechain/modals/success_modal.dart';
import 'package:safechain/widgets/curved_app_bar.dart';
import 'package:safechain/widgets/phone_number_input.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyNumberController;
  late final TextEditingController _emergencyAddressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.userData['full_name']);
    _addressController = TextEditingController(text: widget.userData['address']);
    _contactNumberController = TextEditingController(text: _formatPhoneNumberOnLoad(widget.userData['contact_number']));
    _emergencyNameController = TextEditingController(text: widget.userData['emergency_contact_person_name']);
    _emergencyNumberController = TextEditingController(text: _formatPhoneNumberOnLoad(widget.userData['emergency_contact_number']));
    _emergencyAddressController = TextEditingController(text: widget.userData['emergency_contact_address']);
  }

  String _formatPhoneNumberOnLoad(String? phoneNumber) {
    if (phoneNumber == null) return '';
    // Assuming the phone number from the database is always 10 digits.
    if (phoneNumber.length == 10) {
      return '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 6)}-${phoneNumber.substring(6)}';
    }
    return phoneNumber;
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('residents').doc(user.uid).update({
        'full_name': _fullNameController.text,
        'address': _addressController.text,
        'contact_number': _contactNumberController.text.replaceAll('-', ''),
        'emergency_contact_person_name': _emergencyNameController.text,
        'emergency_contact_number': _emergencyNumberController.text.replaceAll('-', ''),
        'emergency_contact_address': _emergencyAddressController.text,
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SuccessModal(
          title: 'Success!',
          message: 'Your information has been successfully saved.',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      Navigator.of(context).pop();
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _emergencyNameController.dispose();
    _emergencyNumberController.dispose();
    _emergencyAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CurvedAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text('Edit Your Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildEditProfileForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your Full Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Complete Address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your Complete Address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          PhoneNumberInput(label: 'Contact Number', hint: '912-345-6789', controller: _contactNumberController),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyNameController,
            decoration: const InputDecoration(labelText: 'Emergency Contact Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your Emergency Contact Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          PhoneNumberInput(label: 'Emergency Contact Number', hint: '912-345-6789', controller: _emergencyNumberController),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyAddressController,
            decoration: const InputDecoration(labelText: 'Emergency Contact Address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your Emergency Contact Address';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                child: const Text('Discard', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        ],
      ),
    );
  }
}