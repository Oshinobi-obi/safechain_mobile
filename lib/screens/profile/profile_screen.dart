
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safechain/screens/edit_profile/edit_profile_screen.dart';
import 'package:safechain/screens/login/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      setState(() {
        _user = user;
      });
      if (user != null) {
        _fetchUserData(user);
      }
    });
  }

  Future<void> _fetchUserData(User user) async {
    if (mounted) setState(() => _isLoading = true);
    final doc = await FirebaseFirestore.instance.collection('residents').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _userData = doc.data();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref().child('profile_pictures').child(_user!.uid + '.jpg');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('residents').doc(_user!.uid).update({
        'profile_picture_url': downloadUrl,
      });

      setState(() {
        _userData!['profile_picture_url'] = downloadUrl;
      });
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_user != null && !_user!.emailVerified) {
      await _user!.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
      );
    }
  }

  Future<void> _confirmAndLogout() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear Remember Me credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('password');
      
      await FirebaseAuth.instance.signOut();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 16),
                _buildEmailVerificationStatus(),
                const SizedBox(height: 24),
                _buildPersonalInfoSection(),
                const SizedBox(height: 16),
                _buildProfileInfo(),
                const SizedBox(height: 32),
                _buildLogoutButton(),
              ],
            ),
          );
  }

  Widget _buildProfileHeader() {
    final profilePicUrl = _userData?['profile_picture_url'];
    final initials = _userData?['full_name']?.substring(0, 2).toUpperCase() ?? 'N/A';

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
            child: profilePicUrl == null ? Text(initials, style: const TextStyle(fontSize: 40)) : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.camera_alt, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationStatus() {
    final isVerified = _user?.emailVerified ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isVerified ? Colors.green : Colors.red, width: 1),
      ),
      child: Column(
        children: [
          Text(
            isVerified ? 'Email Verified' : 'Email not yet verified!',
            style: TextStyle(color: isVerified ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
          if (!isVerified)
            const SizedBox(height: 8),
          if (!isVerified)
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: _sendVerificationEmail,
                child: const Text('Verify Email'),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => EditProfileScreen(userData: _userData!)),
            ).then((_) => _fetchUserData(_user!)); // Refresh data after editing
          },
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        InfoRow(icon: Icons.person, label: 'Full Name', value: _userData?['full_name'] ?? 'N/A'),
        InfoRow(icon: Icons.email, label: 'Email', value: _userData?['email'] ?? 'N/A'),
        InfoRow(icon: Icons.location_on, label: 'Complete Address', value: _userData?['address'] ?? 'N/A'),
        InfoRow(icon: Icons.phone, label: 'Contact Number', value: _userData?['contact_number'] ?? 'N/A'),
        const Divider(height: 32),
        InfoRow(icon: Icons.contact_mail, label: 'Emergency Contact Name', value: _userData?['emergency_contact_person_name'] ?? 'N/A'),
        InfoRow(icon: Icons.phone, label: 'Emergency Contact Number', value: _userData?['emergency_contact_number'] ?? 'N/A'),
        InfoRow(icon: Icons.location_on, label: 'Emergency Contact Address', value: _userData?['emergency_contact_address'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: _confirmAndLogout,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF20C997),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      child: const Text('Logout', style: TextStyle(fontSize: 18, color: Colors.white)),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF20C997)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(value, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
