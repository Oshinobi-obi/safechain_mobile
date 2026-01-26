
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:safechain/screens/home/home_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as perm;

class AddDeviceFlow extends StatefulWidget {
  const AddDeviceFlow({super.key});

  @override
  State<AddDeviceFlow> createState() => _AddDeviceFlowState();
}

class _AddDeviceFlowState extends State<AddDeviceFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  BluetoothDevice? _selectedDevice;
  String _deviceName = 'Safechain001';

  void _nextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addDeviceToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDevice == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('residents')
          .doc(user.uid)
          .collection('devices')
          .add({
        'name': _deviceName,
        'id': _selectedDevice!.remoteId.toString(),
        'battery': 100, // Default battery
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nextStep();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding device: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [
          EnableBluetoothStep(onEnable: _nextStep, onSkip: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()))),
          PairYourDeviceStep(onStart: _nextStep, onBack: () => _goToStep(0)),
          ScanningStep(
            onDeviceSelected: (device) {
              setState(() => _selectedDevice = device);
              _nextStep();
            },
            onCancel: () => _goToStep(1),
            onNoDevice: () => _goToStep(7),
          ),
          SetUpDeviceStep(
            device: _selectedDevice,
            onAdd: _addDeviceToFirestore,
            onCancel: () => _goToStep(1),
            onNameChanged: (name) => setState(() => _deviceName = name),
          ),
          TestingGatewayStep(onSuccess: _nextStep, onError: () => _goToStep(8)),
          AllSetStep(
            onTestGps: () => _goToStep(6),
            onGoToDeviceList: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
          ),
          GpsTestingStep(onBack: () => _goToStep(5)),
          NoDeviceFoundStep(onTryAgain: () => _goToStep(2)),
          ConnectionUnsuccessfulStep(onTryAgain: () => _goToStep(4), onViewMap: () {}),
        ],
      ),
    );
  }
}

class EnableBluetoothStep extends StatefulWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;
  const EnableBluetoothStep({super.key, required this.onEnable, required this.onSkip});

  @override
  State<EnableBluetoothStep> createState() => _EnableBluetoothStepState();
}

class _EnableBluetoothStepState extends State<EnableBluetoothStep> {
  bool _isRequesting = false;

  Future<void> _enableBluetooth() async {
    setState(() => _isRequesting = true);

    try {
      if (Platform.isAndroid) {
        Map<perm.Permission, perm.PermissionStatus> statuses = await [
          perm.Permission.bluetoothScan,
          perm.Permission.bluetoothConnect,
          perm.Permission.bluetoothAdvertise,
          perm.Permission.location,
        ].request();

        bool allGranted =
        statuses.values.every((status) => status.isGranted == true);

        if (!allGranted) {
          bool anyPermanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);

          if (anyPermanentlyDenied) {
            _showPermissionDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bluetooth permissions are required to continue'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isRequesting = false);
          return;
        }

        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          if(mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please turn on Bluetooth manually from settings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (Platform.isIOS) {
        await perm.Permission.bluetooth.request();
      }

      final isOn = await FlutterBluePlus.isOn;
      if (isOn) {
        widget.onEnable();
      } else {
        if(mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth to continue'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if(mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isRequesting = false);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth and Location permissions are required to scan for devices. Please enable them in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              perm.openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFF20C997)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFD1E9FF),
              child: Image.asset('images/bluetooth-icon.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('Enable Bluetooth', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'We need Bluetooth access to connect to your emergency device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'This allows your phone to communicate with the device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isRequesting ? null : _enableBluetooth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isRequesting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Enable', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onSkip,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Skip for Now', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class PairYourDeviceStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onBack;
  const PairYourDeviceStep({super.key, required this.onStart, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: const Text('Add Device'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFE6F9F3),
                child: Image.asset('images/hotspot-icon.png', width: 50, color: const Color(0xFF20C997)),
              ),
              const SizedBox(height: 32),
              const Text('Pair Your Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Follow the steps to connect your keychain device', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              _buildStep(1, 'Power On Device', 'Hold power button for 3 seconds.', 'images/circle-power.png'),
              const SizedBox(height: 16),
              _buildStep(2, 'Wait for LED', 'Device LED should start blinking.', 'images/lightbulb-icon.png'),
              const SizedBox(height: 16),
              _buildStep(3, 'Start Pairing', 'You are good to go.', 'images/star-icon.png'),
              const Spacer(),
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C997),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Start Pairing', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int num, String title, String sub, String iconPath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20C997),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(num.toString(), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          Image.asset(iconPath, width: 40, color: Colors.white),
        ],
      ),
    );
  }
}

class ScanningStep extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onCancel;
  final VoidCallback onNoDevice;
  const ScanningStep({super.key, required this.onDeviceSelected, required this.onCancel, required this.onNoDevice});

  @override
  State<ScanningStep> createState() => _ScanningStepState();
}

class _ScanningStepState extends State<ScanningStep> {
  late StreamSubscription<List<ScanResult>> _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 11));

      if (mounted && _scanResults.isEmpty) {
        setState(() => _isScanning = false);
        widget.onNoDevice();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onCancel),
        title: const Text('Scanning'),
        centerTitle: true,
        actions: [TextButton(onPressed: widget.onCancel, child: const Text('CANCEL', style: TextStyle(color: Colors.grey)))],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 60),
              if (_isScanning && _scanResults.isEmpty)
                const ScanningPulse(),
              const SizedBox(height: 40),
              const Text(
                'Searching for devices',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _scanResults.isEmpty ? 'Please wait...' : '${_scanResults.length} device(s) found',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 60),
              Expanded(
                child: ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: InkWell(
                        onTap: () => widget.onDeviceSelected(result.device),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFFE6F9F3), borderRadius: BorderRadius.circular(12)),
                                child: Image.asset('images/hotspot-icon.png', width: 24, color: const Color(0xFF20C997)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(result.device.platformName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('ID: ${result.device.remoteId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFFE6F9F3), borderRadius: BorderRadius.circular(20)),
                                child: const Text('Found', style: TextStyle(color: Color(0xFF20C997), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetUpDeviceStep extends StatelessWidget {
  final BluetoothDevice? device;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final Function(String) onNameChanged;
  const SetUpDeviceStep({super.key, this.device, required this.onAdd, required this.onCancel, required this.onNameChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onCancel),
        title: const Text('Set Up Device'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F9F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Image.asset('images/logo.png', height: 60),
                    const SizedBox(height: 24),
                    Text(device?.platformName.isNotEmpty ?? false ? device!.platformName : 'Safechain Device Found', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('ID: ${device?.remoteId ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text('Device Name', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: 'Safechain001',
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  hintText: 'Safechain001',
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20C997),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Add', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestingGatewayStep extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onError;
  const TestingGatewayStep({super.key, required this.onSuccess, required this.onError});

  @override
  State<TestingGatewayStep> createState() => _TestingGatewayStepState();
}

class _TestingGatewayStepState extends State<TestingGatewayStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.delayed(const Duration(seconds: 3), widget.onSuccess);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Transform.scale(
                        scale: 1 + (_controller.value + i / 3) % 1 * 1.5,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD1E9FF).withOpacity(0.3 * (1 - (_controller.value + i / 3) % 1)),
                          ),
                        ),
                      ),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFD1E9FF),
                      child: Image.asset('images/connection-icon.png', width: 50, color: const Color(0xFF007AFF)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            const Text('Testing Gateway Connection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Connecting to LoRa network...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class AllSetStep extends StatelessWidget {
  final VoidCallback onTestGps;
  final VoidCallback onGoToDeviceList;
  const AllSetStep({super.key, required this.onTestGps, required this.onGoToDeviceList});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFE6F9F3),
              child: Image.asset('images/hotspot-icon.png', width: 60, color: const Color(0xFF20C997)),
            ),
            const SizedBox(height: 40),
            const Text('Your Device is Ready!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Your device is connected and ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can now test GPS location tracking',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTestGps,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Test GPS Tracking', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onGoToDeviceList,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Go to device list', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class GpsTestingStep extends StatefulWidget {
  final VoidCallback onBack;
  const GpsTestingStep({super.key, required this.onBack});

  @override
  State<GpsTestingStep> createState() => _GpsTestingStepState();
}

class _GpsTestingStepState extends State<GpsTestingStep> {
  loc.LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    _currentLocation = await location.getLocation();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('GPS Testing'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation != null
              ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
              : const LatLng(14.7120, 121.0387),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.safechain.app',
          ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class NoDeviceFoundStep extends StatelessWidget {
  final VoidCallback onTryAgain;
  const NoDeviceFoundStep({super.key, required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFFEBEE),
              child: Image.asset('images/hotspot-red.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('No Device Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Turn on your device and make sure its nearby, then try scanning again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionUnsuccessfulStep extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onViewMap;
  const ConnectionUnsuccessfulStep({super.key, required this.onTryAgain, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFFEBEE),
              child: Image.asset('images/connection-red.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('Connection Unsuccessful', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Unable to connect to LoRa Gateway. Make sure your device is within range of a gateway and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onViewMap,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('View Gateway Map', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanningPulse extends StatefulWidget {
  const ScanningPulse({super.key});

  @override
  State<ScanningPulse> createState() => _ScanningPulseState();
}

class _ScanningPulseState extends State<ScanningPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _pulseCircle(1.0),
          _pulseCircle(1.4),
          _pulseCircle(1.8),

          // CENTER ICON
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF20C997),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/hotspot-icon.png',
                width: 28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseCircle(double scale) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.scale(
          scale: scale * _controller.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF20C997)
                  .withOpacity(1 - _controller.value),
            ),
          ),
        );
      },
    );
  }
}
