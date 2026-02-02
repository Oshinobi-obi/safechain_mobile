import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/widgets/phone_number_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttermoji/fluttermoji.dart';

class PersonalInformationScreen extends StatefulWidget {
  final UserModel userData;
  const PersonalInformationScreen({super.key, required this.userData});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  List<String> _selectedConditions = [];
  bool _isLoading = false;
  File? _image;
  String? _avatar;

  final List<String> _medicalConditions = [
    'Asthma',
    'Heart Disease',
    'Visually Impaired',
    'Pregnant',
    'Elderly',
    'Speech Impaired',
    'None',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _nameController = TextEditingController(text: widget.userData.name);
    _emailController = TextEditingController(text: widget.userData.email);
    _contactController = TextEditingController(text: widget.userData.contact);
    _addressController = TextEditingController(text: widget.userData.address);

    try {
      if (widget.userData.medicalConditions.isNotEmpty) {
        _selectedConditions = List<String>.from(widget.userData.medicalConditions);
      }
    } catch (e) {
      debugPrint("Error parsing medical conditions: $e");
      _selectedConditions = [];
    }

    _avatar = widget.userData.avatar;

    if (_avatar != null && _avatar!.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fluttermoji', _avatar!);
    }

    if (_contactController.text.isNotEmpty) {
      _contactController.text = PhoneNumberFormatter()
          .formatEditUpdate(TextEditingValue.empty, _contactController.value)
          .text;
    }

    if (mounted) setState(() {});
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
    const String apiUrl = 'https://safechain.site/api/mobile/update_profile.php';

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.fields['resident_id'] = widget.userData.residentId;
    request.fields['name'] = _nameController.text.trim();
    request.fields['email'] = _emailController.text.trim();
    request.fields['address'] = _addressController.text.trim();
    request.fields['contact'] = _contactController.text.replaceAll('-', '').trim();
    request.fields['medical_conditions'] = jsonEncode(_selectedConditions);

    if (_image != null) {
      request.files.add(
          await http.MultipartFile.fromPath('profile_picture', _image!.path));
    } else if (_avatar != null) {
      request.fields['avatar'] = _avatar!;
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print("Update Response Status: ${response.statusCode}");
      print("Update Response Body: $responseBody");

      if (responseBody.isEmpty) {
        throw const FormatException('Server returned an empty response.');
      }

      final decodedBody = jsonDecode(responseBody);
      final message = decodedBody['message'] ?? 'An error occurred.';

      if (!mounted) return;

      if (response.statusCode == 200 && decodedBody['status'] == 'success') {
        if (decodedBody.containsKey('user')) {
          final updatedUser = UserModel.fromJson(decodedBody['user']);
          await SessionManager.saveUser(updatedUser);
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'An unexpected error occurred: $e';
        if (e is FormatException) {
          errorMessage =
          'Invalid server response. Please check the debug logs.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
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
                                    if (!_selectedConditions.contains(condition)) {
                                      _selectedConditions.add(condition);
                                    }
                                  } else {
                                    _selectedConditions.remove(condition);
                                  }
                                });
                                setState(() {});
                              },
                              activeColor: const Color(0xFF20C997),
                              controlAffinity: ListTileControlAffinity.leading,
                              checkboxShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
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

  void _showPictureOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text('Edit Picture', style: TextStyle(fontWeight: FontWeight.bold))),
          content: const Text('Choose an option to set your profile picture.', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20C997),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.face, color: Colors.white),
                  label: const Text('Avatar', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAvatarPicker();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20C997),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _avatar = null;
      });
    }
  }

  void _showAvatarPicker() async {
    final fluttermojiController = FluttermojiFunctions();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Customize Avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: FluttermojiCustomizer(
                autosave: true,
                theme: FluttermojiThemeData(
                  primaryBgColor: Colors.white,
                  secondaryBgColor: const Color(0xFFF1F5F9),
                  labelTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                  boxDecoration: const BoxDecoration(
                    boxShadow: [BoxShadow(blurRadius: 0)],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                final svg = await fluttermojiController.encodeMySVGtoString();
                setState(() {
                  _avatar = svg;
                  _image = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF20C997))),
            ),
          ],
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
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF20C997), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFE6F9F3),
                      backgroundImage: _image != null ? FileImage(_image!) : null,
                      child: _image == null
                          ? (_avatar != null && _avatar!.isNotEmpty)
                          ? FluttermojiCircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[200],
                      )
                          : (widget.userData.profilePictureUrl != null && widget.userData.profilePictureUrl!.isNotEmpty)
                          ? ClipOval(
                        child: Image.network(
                          widget.userData.profilePictureUrl!,
                          fit: BoxFit.cover,
                          width: 110,
                          height: 110,
                        ),
                      )
                          : const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userData.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'User ID: ${widget.userData.residentId}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showPictureOptions,
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
            _buildInputField('Full Name', _nameController),
            const SizedBox(height: 24),
            _buildInputField('Email', _emailController),
            const SizedBox(height: 24),
            _buildContactField(),
            const SizedBox(height: 24),
            _buildInputField('Address', _addressController),
            const SizedBox(height: 24),
            _buildDropdownField(
                'Specific Medical Condition',
                _selectedConditions.isEmpty ? 'Select your condition' : _selectedConditions.join(', '),
                _showMedicalConditions
            ),
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
                : const Text('Save Changes',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {bool enabled = true}) {
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
                Expanded(
                    child: Text(value.isNotEmpty ? value : 'Select your condition',
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}