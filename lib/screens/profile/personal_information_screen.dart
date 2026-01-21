import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safechain/widgets/phone_number_formatter.dart';

class PersonalInformationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PersonalInformationScreen({super.key, required this.userData});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  List<String> _selectedConditions = [];
  bool _isLoading = false;

  final List<String> _medicalConditions = [
    'Asthma', 'Heart Disease', 'Visually Impaired', 'Pregnant', 'Elderly', 'Speech Impaired', 'None', 'Others'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['full_name']);
    _emailController = TextEditingController(text: widget.userData['email']);
    _contactController = TextEditingController(text: widget.userData['contact_number']);
    _addressController = TextEditingController(text: widget.userData['address']);
    _selectedConditions = List<String>.from(widget.userData['medical_conditions'] ?? []);
    
    // Format initial contact number if it exists
    if (_contactController.text.isNotEmpty) {
      _contactController.text = PhoneNumberFormatter().formatEditUpdate(TextEditingValue.empty, _contactController.value).text;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('residents').doc(user.uid).update({
          'full_name': _nameController.text.trim(),
          'contact_number': _contactController.text.replaceAll('-', '').trim(),
          'address': _addressController.text.trim(),
          'medical_conditions': _selectedConditions,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMedicalConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Choose all medical conditions that may affect rescue or treatment.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _medicalConditions.length,
                          itemBuilder: (context, index) {
                            final condition = _medicalConditions[index];
                            final isSelected = _selectedConditions.contains(condition);
                            return CheckboxListTile(
                              title: Text(condition),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    _selectedConditions.add(condition);
                                  } else {
                                    _selectedConditions.remove(condition);
                                  }
                                });
                                setState(() {});
                              },
                              activeColor: const Color(0xFF20C997),
                              controlAffinity: ListTileControlAffinity.leading,
                              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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
          'Personal Information',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            // Profile Section
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF20C997), width: 3),
                    ),
                    child: const CircleAvatar(
                      radius: 55,
                      backgroundColor: Color(0xFFE6F9F3),
                      backgroundImage: AssetImage('images/profile-active.png'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userData['full_name'] ?? 'User',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'User ID: USR-2025-001',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: Image.asset('images/edit-icon.png', width: 20, color: Colors.white),
                    label: const Text('Edit Picture', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20C997),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Form Fields
            _buildInputField('Full Name', _nameController),
            const SizedBox(height: 24),
            _buildInputField('Email', _emailController, enabled: false),
            const SizedBox(height: 24),
            _buildContactField(),
            const SizedBox(height: 24),
            _buildInputField('Address', _addressController),
            const SizedBox(height: 24),
            _buildDropdownField('Specific Medical Condition', _selectedConditions.join(', '), _showMedicalConditions),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20C997),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isLoading 
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: enabled ? Colors.black : Colors.grey),
          decoration: InputDecoration(
            fillColor: const Color(0xFFF1F5F9),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildContactField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Image.asset('images/philippine_flag.png', width: 24),
                  const SizedBox(width: 8),
                  const Text('+63', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  PhoneNumberFormatter(),
                ],
                decoration: const InputDecoration(
                  fillColor: Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(value.isNotEmpty ? value : 'Select your condition', style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
