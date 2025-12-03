
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:safechain/screens/crime/crime_screen.dart';
import 'package:safechain/screens/emergency_sos/emergency_sos_screen.dart';
import 'package:safechain/screens/profile/profile_screen.dart';
import 'package:safechain/widgets/curved_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('residents').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userData = doc.data();
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      HomeContent(userData: _userData),
      const ProfileScreen(),
    ];

    final String displayName = _userData?['full_name']?.split(' ').first ?? 'User';

    final List<PreferredSizeWidget> appBars = <PreferredSizeWidget>[
      CurvedAppBar(
        title: Text('Hi, $displayName!', style: const TextStyle(color: Colors.white, fontSize: 24)),
        bottom: const Text('Welcome back to SafeChain', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      const CurvedAppBar(
        title: Text('Profile', style: TextStyle(color: Colors.white, fontSize: 24)),
        bottom: Text('Your Profile Information', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    ];

    return Scaffold(
      appBar: appBars[_selectedIndex],
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF20C997),
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomeContent({super.key, this.userData});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  LocationData? _currentLocation;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locationData = await location.getLocation();
    if (mounted) {
      setState(() {
        _currentLocation = locationData;
        if (_currentLocation != null) {
          _mapController.move(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!), 15.0);
        }
      });
    }
  }

  void _recenterMap() {
      if (_currentLocation != null) {
          _mapController.move(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!), 15.0);
      }
  }

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = widget.userData?['profile_picture_url'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const DeviceRegistration(),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))],
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(14.700, 121.030),
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=uMG221O3FCXWR3ts0EqP',
                          userAgentPackageName: 'com.safechain.app',
                        ),
                        if (_currentLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                                width: 50,
                                height: 50,
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 23,
                                    backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
                                    child: profilePicUrl == null ? const Icon(Icons.person, size: 25) : null,
                                  ),
                                ),
                              ),
                            ],
                          )
                      ],
                    ),
                  ),
                ),
                Positioned(
                    bottom: 10,
                    right: 10,
                    child: FloatingActionButton(
                        onPressed: _recenterMap,
                        mini: true,
                        child: const Icon(Icons.my_location),
                    ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const PersonalSafetySection(),
        ],
      ),
    );
  }
}

class DeviceRegistration extends StatelessWidget {
  const DeviceRegistration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(hintText: 'Enter your serial number', labelText: 'Serial Number')),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20C997),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
            child: const Text('Register Device', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class PersonalSafetySection extends StatelessWidget {
  const PersonalSafetySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERSONAL SAFETY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Explore ways to get help'),
          const Text('Try demos or set up Personal Safety features', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSafetyButton(context, 'Emergency SOS', 'images/emergency.png', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EmergencySosScreen()));
              }),
              _buildSafetyButton(context, 'Crime', 'images/crime.png', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CrimeScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyButton(BuildContext context, String label, String imagePath, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Image.asset(imagePath, height: 50),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}
