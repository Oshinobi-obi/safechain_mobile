import 'package:flutter/material.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/screens/profile/personal_information_screen.dart';
import 'package:safechain/widgets/fade_page_route.dart';

class ProfileCompletionBanner extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onCompleted;

  const ProfileCompletionBanner({super.key, this.user, this.onCompleted});

  static bool isIncomplete(UserModel user) =>
      user.address.trim().isEmpty || user.contact.trim().isEmpty;

  @override
  State<ProfileCompletionBanner> createState() =>
      _ProfileCompletionBannerState();
}

class _ProfileCompletionBannerState extends State<ProfileCompletionBanner> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _user = widget.user;
    } else {
      _loadUser();
    }
  }

  @override
  void didUpdateWidget(ProfileCompletionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != null) {
      setState(() => _user = widget.user);
    }
  }

  Future<void> _loadUser() async {
    final user = await SessionManager.getUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _onTap() async {
    if (_user == null) return;
    await Navigator.push(
      context,
      FadePageRoute(child: PersonalInformationScreen(userData: _user!)),
    );
    // Refresh after returning
    if (widget.user == null) {
      await _loadUser();
    }
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || !ProfileCompletionBanner.isIncomplete(_user!)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Profile incomplete — tap here to complete your account details.',
                style: TextStyle(
                  color: Color(0xFF7A5800),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFFFB300), size: 18),
          ],
        ),
      ),
    );
  }
}