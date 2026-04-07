import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/screens/notification/notification_screen.dart';
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/services/ble_connection_service.dart';
import 'package:safechain/widgets/offline_banner.dart';
import 'package:safechain/widgets/profile_completion_banner.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/screens/add_device/add_device_flow.dart';
import 'package:safechain/modals/error_modal.dart';
import 'package:safechain/screens/announcement/announcement_screen.dart';
import 'package:safechain/screens/guide/guide_screen.dart';
import 'package:safechain/screens/profile/profile_screen.dart';
import 'package:safechain/widgets/battery_indicator.dart';
import 'package:safechain/widgets/fade_page_route.dart';
import 'package:safechain/screens/tracking/device_tracking_screen.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Device {
  final int deviceId;
  final String name;
  final String btRemoteId;
  final int battery;

  Device({required this.deviceId, required this.name, required this.btRemoteId, required this.battery});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] is int ? json['device_id'] : int.tryParse(json['device_id'].toString()) ?? 0,
      name: json['name'] ?? 'Unnamed Device',
      btRemoteId: json['bt_remote_id'] ?? 'No ID',
      battery: json['battery'] is int ? json['battery'] : int.tryParse(json['battery'].toString()) ?? 0,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  Timer? _notifTimer;
  StreamSubscription<int>? _notifStream;
  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardAnimations = [];

  @override
  void initState() {
    super.initState();
    _updateNotificationCount();
    // ── Real-time: react instantly when a notification is added ──
    _notifStream = NotificationService.countStream.listen((count) {
      if (mounted) setState(() => _unreadNotifications = count);
    });
    // ── Fallback poll every 5s (catches external events) ──
    _notifTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateNotificationCount();
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _notifStream?.cancel();
    for (final c in _cardControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _updateNotificationCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _updateNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      DevicesContent(updateNotificationCount: _updateNotificationCount),
      const GuideScreen(),
      const AnnouncementScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // SafeArea(bottom:false) gives the Column a top inset equal to the status
      // bar height, so the OfflineBanner starts strictly below the system UI —
      // the status bar keeps its natural colour regardless of banner state.
      // bottom:false is important — the BottomNavigationBar handles its own
      // bottom safe area separately via the bottomNavigationBar slot.
      // MediaQuery.removePadding(removeTop:true) on the tab content cancels the
      // top inset for DevicesContent which already adds padding.top internally,
      // preventing any double-offset gap.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: widgetOptions.elementAt(_selectedIndex),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Image.asset(_selectedIndex == 0 ? 'images/mobile-active.png' : 'images/mobile-inactive.png', width: 24, height: 24),
              label: 'Devices',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(_selectedIndex == 1 ? 'images/guide-active.png' : 'images/guide-inactive.png', width: 24, height: 24),
              label: 'Guide',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(_selectedIndex == 2 ? 'images/announcement-active.png' : 'images/announcement-inactive.png', width: 24, height: 24),
              label: 'Announcement',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(_selectedIndex == 3 ? 'images/profile-active.png' : 'images/profile-inactive.png', width: 24, height: 24),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF20C997),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

class DevicesContent extends StatefulWidget {
  final Future<void> Function() updateNotificationCount;
  const DevicesContent({super.key, required this.updateNotificationCount});

  @override
  State<DevicesContent> createState() => _DevicesContentState();
}

class _DevicesContentState extends State<DevicesContent> with TickerProviderStateMixin {
  Future<List<Device>>? _devicesFuture;
  UserModel? _currentUser;
  int _unreadNotifications = 0;

  Timer? _notifTimer;
  StreamSubscription<int>? _notifStream;
  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardAnimations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateCount();
    // ── Real-time bell update via stream ──
    _notifStream = NotificationService.countStream.listen((count) {
      if (mounted) setState(() => _unreadNotifications = count);
    });
    // ── Fallback poll every 5s ──
    _notifTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateCount();
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _notifStream?.cancel();
    for (final c in _cardControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await SessionManager.getUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
        _devicesFuture = _fetchDevices(user.residentId);
      });
    }
  }

  Future<void> _updateCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  Future<void> _navigateAndRefresh() async {
    final result = await Navigator.push(context, FadePageRoute(child: const NotificationScreen()));
    if (result == true) {
      _updateCount();
    }
  }

  Future<List<Device>> _fetchDevices(String residentId) async {
    final uri = Uri.parse('https://safechain.site/api/mobile/get_devices.php?resident_id=$residentId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        final List<dynamic> deviceList = body['devices'];
        return deviceList.map((json) => Device.fromJson(json)).toList();
      }
    }
    throw Exception('Failed to load devices');
  }

  void _refreshDevices() {
    if (_currentUser != null) {
      setState(() {
        _devicesFuture = _fetchDevices(_currentUser!.residentId);
      });
    }
  }

  // ── SAVE: rename a device via API ──────────────────────────────
  Future<void> _renameDevice(int deviceId, String newName) async {
    try {
      final response = await http.post(
        Uri.parse('https://safechain.site/api/mobile/update_device.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'device_id': deviceId, 'name': newName}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        _refreshDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device name updated!'), backgroundColor: Color(0xFF20C997)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['message'] ?? 'Failed to update name.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UNLINK: delete a device via API ────────────────────────────
  Future<void> _unlinkDevice(int deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('https://safechain.site/api/mobile/delete_device.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'device_id': deviceId}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        _refreshDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device unlinked successfully.'), backgroundColor: Color(0xFF20C997)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['message'] ?? 'Failed to unlink device.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeviceSettings(BuildContext context, Device device) {
    final TextEditingController nameController = TextEditingController(text: device.name);
    bool isSaving = false;
    bool isUnlinking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                // viewInsets.bottom = keyboard height
                // padding.bottom    = system navigation bar height
                bottom: MediaQuery.of(bc).viewInsets.bottom + MediaQuery.of(bc).padding.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Device Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${device.btRemoteId}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── SAVE BUTTON ──
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20C997),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: isSaving ? null : () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device name cannot be empty.')),
                        );
                        return;
                      }
                      setModalState(() => isSaving = true);
                      Navigator.pop(bc);
                      await _renameDevice(device.deviceId, newName);
                    },
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  // ── UNLINK BUTTON ──
                  TextButton(
                    onPressed: isUnlinking ? null : () async {
                      // Confirm dialog before unlinking
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Unlink Device'),
                          content: Text('Are you sure you want to unlink "${device.name}"? This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Unlink', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setModalState(() => isUnlinking = true);
                        Navigator.pop(bc);
                        await _unlinkDevice(device.deviceId);
                      }
                    },
                    child: isUnlinking
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                        : const Text('Unlink Device', style: TextStyle(color: Colors.red, fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _buildAnimatedControllers(int count) {
    // Only rebuild if count changed
    if (_cardControllers.length == count) return;
    for (final c in _cardControllers) { c.dispose(); }
    _cardControllers.clear();
    _cardAnimations.clear();
    for (int i = 0; i < count; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _cardControllers.add(controller);
      _cardAnimations.add(CurvedAnimation(parent: controller, curve: Curves.easeOut));
      // Stagger: each card starts 80ms after the previous
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = _currentUser?.name ?? 'User';

    return FutureBuilder<List<Device>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          List<Device> devices = [];
          if (snapshot.hasData) {
            devices = snapshot.data!;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Container(
                      height: 420,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF20C997),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                    ),
                    Positioned(top: -50, right: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
                    Positioned(bottom: 20, left: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 32),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset('images/logo.png', height: 50),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('SafeChain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                      Text('Residents', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _navigateAndRefresh,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                                      child: Image.asset('images/Bell.png', height: 24, color: Colors.white),
                                    ),
                                    if (_unreadNotifications > 0)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Color(0xFFF87171), shape: BoxShape.circle),
                                          child: Text('$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 18)),
                                    Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                                child: CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.white30,
                                  child: _currentUser?.avatar != null
                                      ? FluttermojiCircleAvatar(radius: 35,)
                                      : _currentUser?.profilePictureUrl != null
                                      ? ClipOval(child: Image.network(_currentUser!.profilePictureUrl!, fit: BoxFit.cover, width: 70, height: 70,))
                                      : const Icon(Icons.person, size: 35, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Devices', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                    Text(devices.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final user = _currentUser;
                                    final incomplete = user == null ||
                                        user.address.trim().isEmpty ||
                                        user.contact.trim().isEmpty;
                                    if (incomplete) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => const ErrorModal(
                                          title: 'Profile Incomplete',
                                          message: 'Please complete your profile details (address & contact) before adding a device.',
                                        ),
                                      );
                                      return;
                                    }
                                    await Navigator.push(context, FadePageRoute(child: const AddDeviceFlow()));
                                    _refreshDevices();
                                  },
                                  icon: const Icon(Icons.add, color: Color(0xFF20C997), size: 20),
                                  label: const Text('Add Device', style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: ProfileCompletionBanner()),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator(color: Color(0xFF20C997))))),

              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: Color(0xFFEF4444),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Internet Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your devices cannot be loaded right now.\nPlease check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _refreshDevices,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20C997),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (devices.isEmpty && snapshot.connectionState != ConnectionState.waiting && !snapshot.hasError)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: Center(child: Text("Connect your first SafeChain device now!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 18))),
                  ),
                ),

              if (devices.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        _buildAnimatedControllers(devices.length);
                        final device = devices[index];
                        final anim = index < _cardAnimations.length
                            ? _cardAnimations[index]
                            : const AlwaysStoppedAnimation(1.0);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(anim as Animation<double>),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildDeviceCard(context, device),
                            ),
                          ),
                        );
                      },
                      childCount: devices.length,
                    ),
                  ),
                ),
            ],
          );
        });
  }

  Widget _buildDeviceCard(BuildContext context, Device device) {
    return DeviceCard(
      device: device,
      onSettingsPressed: () => _showDeviceSettings(context, device),
    );
  }
}

// ─────────────────────────────────────────────────
// DEVICE CARD (STATEFUL FOR BLUETOOTH TRACKING)
// ─────────────────────────────────────────────────
class DeviceCard extends StatefulWidget {
  final Device device;
  final VoidCallback onSettingsPressed;

  const DeviceCard({super.key, required this.device, required this.onSettingsPressed});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  late BluetoothDevice _bleDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _bleDevice = BluetoothDevice.fromId(widget.device.btRemoteId);

    _connectionSubscription = _bleDevice.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
          _isConnecting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isConnecting) return;

    if (_connectionState == BluetoothConnectionState.connected) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disconnect Device'),
          content: Text('Are you sure you want to disconnect from ${widget.device.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Stop the background service + disconnect BLE
        await BleConnectionService.instance.stop();
      }
    } else {
      setState(() => _isConnecting = true);
      try {
        // Start background BLE service — keeps device connected even when
        // the screen is off or the user navigates away
        await BleConnectionService.instance.start(
          widget.device.btRemoteId,
          widget.device.name,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not connect to ${widget.device.name}. Is it turned on?'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _connectionState == BluetoothConnectionState.connected;
    final Color statusColor = _isConnecting
        ? Colors.orange
        : (isConnected ? const Color(0xFF20C997) : Colors.grey);
    final String statusText = _isConnecting
        ? 'Connecting...'
        : (isConnected ? 'Connected' : 'Disconnected (Tap to connect)');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _toggleConnection, // Tap anywhere on the card to connect/disconnect
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFE6F9F3), borderRadius: BorderRadius.circular(15)),
                      child: Image.asset('images/mobile-active.png', width: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('ID: ${widget.device.btRemoteId}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 6),

                          // --- NEW CONNECTION STATUS INDICATOR ---
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    BatteryIndicator(charge: widget.device.battery),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                              context,
                              FadePageRoute(
                                  child: DeviceTrackingScreen(
                                    deviceId: widget.device.btRemoteId,
                                    deviceName: widget.device.name,
                                  )
                              )
                          );
                        },
                        icon: Image.asset('images/gps-icon.png', width: 20, color: Colors.white),
                        label: const Text('Test GPS', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF20C997), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onSettingsPressed,
                        icon: Image.asset('images/gear-icon.png', width: 20, color: Colors.grey),
                        label: const Text('Settings', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey.shade200, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}