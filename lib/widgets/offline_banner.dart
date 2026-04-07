import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safechain/services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {

  bool _isOnline = true;
  bool _showingOnlineBanner = false;

  StreamSubscription<bool>? _subscription;
  Timer? _dismissTimer;

  late AnimationController _animController;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();

    _isOnline = ConnectivityService().isOnline;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    if (!_isOnline) _animController.value = 1.0;

    _subscription = ConnectivityService().stream.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _onConnectivityChanged(bool isOnline) {
    if (!mounted) return;
    _dismissTimer?.cancel();

    setState(() {
      _isOnline = isOnline;

      if (isOnline) {
        _showingOnlineBanner = true;
        _animController.forward();
        _dismissTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          _animController.reverse().then((_) {
            if (mounted) setState(() => _showingOnlineBanner = false);
          });
        });
      } else {
        _showingOnlineBanner = false;
        _animController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = !_isOnline || _showingOnlineBanner;

    if (!visible) return const SizedBox.shrink();

    final bool showingOnline = _isOnline && _showingOnlineBanner;
    final Color bgColor =
    showingOnline ? const Color(0xFF20C997) : Colors.red.shade600;
    final IconData icon =
    showingOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final String message = showingOnline
        ? 'Internet is back online!'
        : 'You are currently Offline';

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}