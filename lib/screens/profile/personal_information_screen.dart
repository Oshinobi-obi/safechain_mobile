import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/widgets/phone_number_formatter.dart';
import 'package:safechain/modals/error_modal.dart';
import 'package:safechain/modals/success_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttermoji/fluttermoji.dart';

const Color _kGreen = Color(0xFF20C997);
const Color _kBg    = Color(0xFFF1F5F9);

class PersonalInformationScreen extends StatefulWidget {
  final UserModel userData;
  const PersonalInformationScreen({super.key, required this.userData});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  // ── Controllers ───────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  final TextEditingController _othersController = TextEditingController();

  // ── Validation errors ─────────────────────────────────────────
  String? _nameError;
  String? _emailError;
  String? _contactError;
  String? _addressError;

  // ── Medical conditions ────────────────────────────────────────
  List<String> _selectedConditions = [];
  bool _hasOthers = false;

  final List<String> _medicalConditions = [
    'Asthma',
    'Heart Disease',
    'Visually Impaired',
    'Pregnant',
    'Elderly',
    'Speech Impaired',
    'None',
  ];

  // ── Other state ───────────────────────────────────────────────
  bool _isLoading = false;
  File? _image;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _nameController    = TextEditingController(text: widget.userData.name);
    _emailController   = TextEditingController(text: widget.userData.email);
    _contactController = TextEditingController(text: widget.userData.contact);
    _addressController = TextEditingController(text: widget.userData.address);

    // Add real-time validation listeners
    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
    _contactController.addListener(_validateContact);
    _addressController.addListener(_validateAddress);

    try {
      if (widget.userData.medicalConditions.isNotEmpty) {
        final all = List<String>.from(widget.userData.medicalConditions);
        // Separate "Others: ..." from standard conditions
        final othersEntry = all.firstWhere(
              (c) => c.startsWith('Others:'),
          orElse: () => '',
        );
        if (othersEntry.isNotEmpty) {
          _hasOthers = true;
          _othersController.text = othersEntry.replaceFirst('Others:', '').trim();
          all.remove(othersEntry);
          // Also check if plain 'Others' is in list
          all.remove('Others');
        }
        _selectedConditions = all;
      }
    } catch (e) {
      _selectedConditions = [];
    }

    _avatar = widget.userData.avatar;
    if (_avatar != null && _avatar!.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fluttermoji', _avatar!);
    }

    if (_contactController.text.isNotEmpty) {
      _contactController.text = PhoneNumberFormatter()
          .formatEditUpdate(
          TextEditingValue.empty, _contactController.value)
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
    _othersController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────
  void _validateName() {
    final val = _nameController.text.trim();
    setState(() {
      if (val.isEmpty) {
        _nameError = 'Full name is required.';
      } else if (val.length < 2) {
        _nameError = 'Name must be at least 2 characters.';
      } else {
        _nameError = null;
      }
    });
  }

  void _validateEmail() {
    final val = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    setState(() {
      if (val.isEmpty) {
        _emailError = 'Email is required.';
      } else if (!emailRegex.hasMatch(val)) {
        _emailError = 'Enter a valid email address.';
      } else {
        _emailError = null;
      }
    });
  }

  void _validateContact() {
    final digits = _contactController.text.replaceAll('-', '').replaceAll(' ', '');
    setState(() {
      if (digits.isEmpty) {
        _contactError = 'Contact number is required.';
      } else if (!RegExp(r'^[89]\d{9}$').hasMatch(digits)) {
        _contactError = 'Enter a valid Philippine mobile number (e.g. 912-3456-789).';
      } else {
        _contactError = null;
      }
    });
  }

  void _validateAddress() {
    setState(() {
      _addressError = _addressController.text.trim().isEmpty
          ? 'Address is required.'
          : null;
    });
  }

  bool get _isFormValid {
    _validateName();
    _validateEmail();
    _validateContact();
    _validateAddress();
    return _nameError == null &&
        _emailError == null &&
        _contactError == null &&
        _addressError == null;
  }

  // ── Build final medical condition list ────────────────────────
  List<String> get _finalConditions {
    final list = List<String>.from(_selectedConditions);
    if (_hasOthers) {
      final othersText = _othersController.text.trim();
      list.add(othersText.isNotEmpty ? 'Others: $othersText' : 'Others');
    }
    return list;
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);
    const String apiUrl = 'https://safechain.site/api/mobile/update_profile.php';

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.fields['resident_id']        = widget.userData.residentId;
    request.fields['name']               = _nameController.text.trim();
    request.fields['email']              = _emailController.text.trim();
    request.fields['address']            = _addressController.text.trim();
    request.fields['contact']            = _contactController.text.replaceAll('-', '').trim();
    request.fields['medical_conditions'] = jsonEncode(_finalConditions);

    if (_image != null) {
      request.files.add(
          await http.MultipartFile.fromPath('profile_picture', _image!.path));
    } else if (_avatar != null) {
      request.fields['avatar'] = _avatar!;
    }

    try {
      final response    = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (responseBody.isEmpty) {
        throw const FormatException('Server returned an empty response.');
      }

      final decodedBody = jsonDecode(responseBody);
      final message     = decodedBody['message'] ?? 'An error occurred.';

      if (!mounted) return;

      if (response.statusCode == 200 && decodedBody['status'] == 'success') {
        if (decodedBody.containsKey('user')) {
          final updatedUser = UserModel.fromJson(decodedBody['user']);
          await SessionManager.saveUser(updatedUser);
        }
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => SuccessModal(
            title: 'Profile Updated',
            message: message,
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        showDialog(
          context: context,
          builder: (_) => ErrorModal(
            title: 'Update Failed',
            message: message,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is FormatException
            ? 'Invalid server response.'
            : 'An unexpected error occurred: $e';
        showDialog(
          context: context,
          builder: (_) => ErrorModal(
            title: 'Unexpected Error',
            message: errorMessage,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Medical conditions bottom sheet ──────────────────────────
  void _showMedicalConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
            final bottomPadding = MediaQuery.of(ctx).padding.bottom;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (_, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(bottom: keyboardHeight),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Choose all medical conditions that may affect rescue or treatment.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            children: [
                              // Standard conditions
                              ..._medicalConditions.map((condition) {
                                final isSelected = _selectedConditions.contains(condition);
                                return CheckboxListTile(
                                  title: Text(condition),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setModalState(() {
                                      setState(() {
                                        if (value == true) {
                                          // If selecting a standard condition while Others is active, deselect Others
                                          if (!_selectedConditions.contains(condition)) {
                                            _selectedConditions.add(condition);
                                          }
                                        } else {
                                          _selectedConditions.remove(condition);
                                        }
                                      });
                                    });
                                  },
                                  activeColor: _kGreen,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                );
                              }),

                              // "Others" option
                              CheckboxListTile(
                                title: const Text('Others'),
                                value: _hasOthers,
                                onChanged: (bool? value) {
                                  setModalState(() {
                                    setState(() {
                                      _hasOthers = value ?? false;
                                      if (_hasOthers) {
                                        // Uncheck all other conditions
                                        _selectedConditions.clear();
                                      } else {
                                        _othersController.clear();
                                      }
                                    });
                                  });
                                },
                                activeColor: _kGreen,
                                controlAffinity: ListTileControlAffinity.leading,
                                checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),

                              // Textbox for Others
                              if (_hasOthers)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                  child: TextField(
                                    controller: _othersController,
                                    autofocus: true,
                                    onTap: () {
                                      // Scroll down so the field is visible above keyboard
                                      Future.delayed(const Duration(milliseconds: 300), () {
                                        scrollController.animateTo(
                                          scrollController.position.maxScrollExtent,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                        );
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Describe your condition...',
                                      fillColor: _kBg,
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text('Done',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Picture options ───────────────────────────────────────────
  void _showPictureOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
            child: Text('Edit Picture',
                style: TextStyle(fontWeight: FontWeight.bold))),
        content: const Text('Choose an option to set your profile picture.',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text('Gallery',
                    style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.face, color: Colors.white),
                label: const Text('Avatar',
                    style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  _showAvatarPicker();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker     = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image  = File(pickedFile.path);
        _avatar = null;
      });
    }
  }

  void _showAvatarPicker() {
    final fluttermojiController = FluttermojiFunctions();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customize Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: FluttermojiCustomizer(
              autosave: true,
              theme: FluttermojiThemeData(
                primaryBgColor: Colors.white,
                secondaryBgColor: const Color(0xFFF1F5F9),
                labelTextStyle:
                const TextStyle(fontWeight: FontWeight.bold),
                boxDecoration: const BoxDecoration(
                    boxShadow: [BoxShadow(blurRadius: 0)]),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              final svg =
              await fluttermojiController.encodeMySVGtoString();
              setState(() {
                _avatar = svg;
                _image  = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: _kGreen)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Build medical condition display string
    final conditionDisplay = [
      ..._selectedConditions,
      if (_hasOthers)
        _othersController.text.trim().isNotEmpty
            ? 'Others: ${_othersController.text.trim()}'
            : 'Others',
    ].join(', ');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Information',
          style:
          TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            // ── Profile picture ──────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: _kGreen, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFE6F9F3),
                      backgroundImage:
                      _image != null ? FileImage(_image!) : null,
                      child: _image == null
                          ? (_avatar != null && _avatar!.isNotEmpty)
                          ? FluttermojiCircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey[200])
                          : (widget.userData.profilePictureUrl != null &&
                          widget.userData.profilePictureUrl!
                              .isNotEmpty)
                          ? ClipOval(
                        child: Image.network(
                          widget.userData.profilePictureUrl!,
                          fit: BoxFit.cover,
                          width: 110,
                          height: 110,
                        ),
                      )
                          : const Icon(Icons.person,
                          size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.userData.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('User ID: ${widget.userData.residentId}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showPictureOptions,
                    icon: Image.asset('images/edit-icon.png',
                        width: 20, color: Colors.white),
                    label: const Text('Edit Picture',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── Fields ───────────────────────────────────────
            _buildInputField('Full Name', _nameController,
                error: _nameError),
            const SizedBox(height: 24),
            _buildInputField('Email', _emailController,
                error: _emailError),
            const SizedBox(height: 24),
            _buildContactField(),
            const SizedBox(height: 24),
            _buildInputField('Address', _addressController,
                error: _addressError),
            const SizedBox(height: 24),
            _buildMedicalField(
                conditionDisplay.isEmpty
                    ? 'Select your condition'
                    : conditionDisplay),
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
              backgroundColor: _kGreen,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
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

  // ── Input field ───────────────────────────────────────────────
  Widget _buildInputField(
      String label,
      TextEditingController controller, {
        bool enabled = true,
        String? error,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
              color: enabled ? Colors.black : Colors.grey),
          decoration: InputDecoration(
            fillColor: error != null
                ? const Color(0xFFFFF0F0)
                : _kBg,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            // errorBorder is what Flutter actually uses when errorText is set
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: _kGreen, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 18),
            errorText: error,
            errorStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── Contact field ─────────────────────────────────────────────
  Widget _buildContactField() {
    final hasError = _contactError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Number',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: hasError ? const Color(0xFFFFF0F0) : _kBg,
                border: hasError
                    ? Border.all(color: Colors.red, width: 1.2)
                    : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('images/philippine_flag.png', width: 24),
                  const SizedBox(width: 8),
                  const Text('+63',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    PhoneNumberFormatter(),
                  ],
                  decoration: InputDecoration(
                    fillColor:
                    hasError ? const Color(0xFFFFF0F0) : _kBg,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      borderSide: hasError
                          ? const BorderSide(color: Colors.red, width: 1.2)
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      borderSide: hasError
                          ? const BorderSide(color: Colors.red, width: 1.2)
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      borderSide: BorderSide(
                          color: hasError ? Colors.red : _kGreen,
                          width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 25, top: 6),
            child: Text(
              _contactError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ── Medical condition field ────────────────────────────────────
  Widget _buildMedicalField(String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Specific Medical Condition',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: const Text('Optional',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A5800),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showMedicalConditions,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 16,
                      color: displayValue == 'Select your condition'
                          ? Colors.grey
                          : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}