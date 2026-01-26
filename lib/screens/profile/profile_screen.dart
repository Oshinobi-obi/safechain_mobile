import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/screens/login/login_screen.dart';
import 'package:safechain/screens/profile/personal_information_screen.dart';
import 'package:safechain/screens/profile/emergency_contacts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (mounted) setState(() => _isLoading = true);
    final user = await SessionManager.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    }
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() => _notificationsEnabled = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications enabled'), backgroundColor: Color(0xFF20C997)));
      } else {
        setState(() => _notificationsEnabled = false);
        if (status.isPermanentlyDenied) _showPermissionDialog();
      }
    } else {
      _showDisableNotificationDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Please enable notification permissions in your app settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.of(context).pop(); openAppSettings(); }, child: const Text('Open Settings', style: TextStyle(color: Color(0xFF20C997)))),
        ],
      ),
    );
  }

  void _showDisableNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Notifications'),
        content: const Text('To disable notifications, please go to your device settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.of(context).pop(); openAppSettings(); }, child: const Text('Open Settings', style: TextStyle(color: Color(0xFF20C997)))),
        ],
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await SessionManager.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final UserModel user = _currentUser!;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF20C997),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const CircleAvatar(radius: 50, backgroundColor: Colors.white30, backgroundImage: AssetImage('images/profile-picture.png')),
                  ),
                  const SizedBox(height: 16),
                  Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('User ID: ${user.residentId}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('General'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _buildMenuItem('Personal Information', 'images/user-blue.png', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PersonalInformationScreen(userData: user)),
                    ).then((_) => _loadUserData()); // Refresh data when returning
                  }),
                  _buildMenuItem('Emergency Contacts', 'images/phone-red.png', () {
                     // You might want to pass the user object here too
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()));
                  }),
                  _buildMenuItem('Change Password', 'images/lock-yellow.png', () {}),
                  _buildMenuItem('Privacy Policy', 'images/document-green.png', () {}),
                  _buildMenuItem('Terms of Use', 'images/document-orange.png', () {}),
                  _buildSwitchItem('Notifications', 'images/bell-purple.png'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('About'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset('images/warning-gray.png', width: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('App Version', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _confirmAndLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF87171),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('images/logout-icon.png', width: 24, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Logout', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))),
    );
  }

  Widget _buildMenuItem(String title, String iconPath, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Image.asset(iconPath, width: 28)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.black),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(String title, String iconPath) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Image.asset(iconPath, width: 28)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Switch(value: _notificationsEnabled, onChanged: _handleNotificationToggle, activeColor: const Color(0xFF20C997)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
