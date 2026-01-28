import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/screens/add_device/add_device_flow.dart';
import 'package:safechain/screens/announcement/announcement_screen.dart';
import 'package:safechain/screens/guide/guide_screen.dart';
import 'package:safechain/screens/profile/profile_screen.dart';
import 'package:safechain/widgets/battery_indicator.dart';

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      const DevicesContent(), // Changed to const
      const GuideScreen(),
      const AnnouncementScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: widgetOptions.elementAt(_selectedIndex),
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
  const DevicesContent({super.key});

  @override
  State<DevicesContent> createState() => _DevicesContentState();
}

class _DevicesContentState extends State<DevicesContent> {
  Future<List<Device>>? _devicesFuture;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    // Load user data and then fetch devices
    _loadData();
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
    // If the API call fails or status is not success, throw an exception.
    throw Exception('Failed to load devices');
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
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
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
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                                    child: Image.asset('images/Bell.png', height: 24, color: Colors.white),
                                  ),
                                  Positioned(
                                    right: -4, top: -4,
                                    child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFF87171), shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                  ),
                                ],
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
                                child: const CircleAvatar(radius: 35, backgroundColor: Colors.white30, backgroundImage: AssetImage('images/profile-picture.png')),
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
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDeviceFlow()));
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
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator(color: Color(0xFF20C997))))),
              
              if (snapshot.hasError)
                 SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32.0), child: Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red))))),

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
                        final device = devices[index];
                        return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildDeviceCard(context, device));
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
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
                    Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('ID: ${device.btRemoteId}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              BatteryIndicator(charge: device.battery),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Image.asset('images/gps-icon.png', width: 20, color: Colors.white),
                  label: const Text('Test GPS', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF20C997), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Image.asset('images/gear-icon.png', width: 20, color: Colors.grey),
                  label: const Text('Settings', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey.shade200, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}